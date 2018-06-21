#!/bin/bash

warnuser(){
  cat << EOF
###########
# WARNING #
###########
This script is distributed WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND
Beware ImageStreams objects are not importables due to the way they work
See https://github.com/openshift/openshift-ansible-contrib/issues/967
for more information
EOF
}

die(){
  echo "$1"
  exit $2
}

usage(){
  echo "$0 <projectdirectory>"
  echo "  projectdirectory  The directory where the exported objects are hosted"
  echo "Examples:"
  echo "    $0 ~/backup/myproject"
  warnuser
}

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]
then
  usage
  die "Missing project directory" 3
fi

for i in oc
do
  command -v $i >/dev/null 2>&1 || die "$i required but not found" 3
done

warnuser
#read -p "Are you sure? " -n 1 -r
#echo    # (optional) move to a new line
#if [[ ! $REPLY =~ ^[Yy]$ ]]
#then
#    die "User cancel" 4
#fi

PROJECTPATH=$1
SRC_PROJECT=$(jq -r .metadata.name ${PROJECTPATH}/ns.json)
TGT_PROJECT=$SRC_PROJECT
REGISTRY_IP=$(ssh master1 host docker-registry.default.svc | cut -d' ' -f 4)

if [ -n "$2" ]; then
  TGT_PROJECT="$2"
  echo "Importing into project ${TGT_PROJECT}"
fi

$(oc get projects -o name | grep "^projects/${TGT_PROJECT}\$" -q) && \
  die "Project ${TGT_PROJECT} exists" 4

jq ".metadata.name = \"${TGT_PROJECT}\"" ${PROJECTPATH}/ns.json | oc create -f -
sleep 2

# First we create optional objects
for object in limitranges resourcequotas
do
  [[ -f ${PROJECTPATH}/${object}.json ]] && \
    jq ".metadata.namespace = \"${TGT_PROJECT}\"" ${PROJECTPATH}/${object}.json | \
    oc create -f - -n ${TGT_PROJECT}
done

[[ -f ${PROJECTPATH}/rolebindings.json ]] && \
  jq ".metadata.namespace = \"${TGT_PROJECT}\"" ${PROJECTPATH}/rolebindings.json | \
  jq ".subjects[].namespace = \"${TGT_PROJECT}\"" | \
  jq ".userNames = [.userNames[]? | sub(\"${SRC_PROJECT}\"; \"${TGT_PROJECT}\")]" | \
  jq ".groupNames = [.groupNames[]? | sub(\"${SRC_PROJECT}\"; \"${TGT_PROJECT}\")]" | \
  oc create -f - -n ${TGT_PROJECT}

for object in rolebindingrestrictions secrets serviceaccounts podpreset poddisruptionbudget templates cms egressnetworkpolicies iss pvcs routes hpas
do
  [[ -f ${PROJECTPATH}/${object}.json ]] && \
    jq ".metadata.namespace = \"${TGT_PROJECT}\"" ${PROJECTPATH}/${object}.json | \
    oc create -f - -n ${TGT_PROJECT}
done

# SCC assignments to service accounts
if compgen -G "${PROJECTPATH}/scc_*.json" >/dev/null; then
  for sa in ${PROJECTPATH}/scc_*.json
  do
    safile=$(echo ${sa##*/})
    SANAME=$(echo ${safile} | sed "s/scc_\(.*\)\.json$/\1/")
    for scc in $(jq -r '' ${sa})
    do
      oc adm policy add-scc-to-user  -n ${TGT_PROJECT} ${scc} -z ${SANAME}
    done
  done
fi

# Services & endpoints
for svc in ${PROJECTPATH}/svc_*.json
do
  oc create -f ${svc} -n ${TGT_PROJECT}
done

if compgen -G "${PROJECTPATH}/endpoint_*.json" >/dev/null; then
  for endpoint in ${PROJECTPATH}/endpoint_*.json
  do
    epfile=$(echo ${endpoint##*/})
    EPNAME=$(echo ${epfile} | sed "s/endpoint_\(.*\)\.json$/\1/")
    echo "Checking ${EPNAME}"
    if ! oc get endpoints ${EPNAME} -n ${TGT_PROJECT} >/dev/null 2>&1; then
      jq ".subsets[].addresses[].targetRef.namespace = \"${TGT_PROJECT}\"" ${endpoint} | \
        oc create -f - -n ${TGT_PROJECT}
    fi
  done
fi

# More objects, this time those can create apps
[[ -f ${PROJECTPATH}/bcs.json ]] && \
  jq ".metadata.namespace = \"${TGT_PROJECT}\"" ${PROJECTPATH}/bcs.json | \
  oc create -f - -n ${TGT_PROJECT}

# Builds are referenced by deployments and may be needed for rolling back
# to a previous image version. A S2I build object does not define 
# the source version that was used for the build though. If we create 
# the build object and OpenShift runs the build, it would use the latest 
# source version, and the image would be different than the one that was 
# created by the original build.

#[[ -f ${PROJECTPATH}/builds.json ]] && \
#  jq ".status.config.namespace = \"${TGT_PROJECT}\" | .metadata.namespace = \"${TGT_PROJECT}\"" ${PROJECTPATH}/builds.json | \
#  oc create -f - -n ${TGT_PROJECT}

# Restore DCs
# If patched exists, restore it, otherwise, restore the plain one
if compgen -G "${PROJECTPATH}/dc_*.json" >/dev/null; then
  for dc in ${PROJECTPATH}/dc_*.json
  do
    dcfile=$(echo ${dc##*/})
    [[ ${dcfile} == dc_*_patched.json ]] && continue
    DCNAME=$(echo ${dcfile} | sed "s/dc_\(.*\)\.json$/\1/")
    if [ -s ${PROJECTPATH}/dc_${DCNAME}_patched.json ]
    then
      jq ".spec.triggers = (.spec.triggers | map((select(.type == \"ImageChange\" and .imageChangeParams.from.namespace == \"${SRC_PROJECT}\").imageChangeParams.from.namespace) |= \"${TGT_PROJECT}\"))" ${PROJECTPATH}/dc_${DCNAME}_patched.json | \
      sed -e "s/docker-registry.default.svc/${REGISTRY_IP}/g" | \
      oc create -f - -n ${TGT_PROJECT}
    else
      jq ".spec.triggers = (.spec.triggers | map((select(.type == \"ImageChange\" and .imageChangeParams.from.namespace == \"${SRC_PROJECT}\").imageChangeParams.from.namespace) |= \"${TGT_PROJECT}\"))" ${dc} | \
      sed -e "s/docker-registry.default.svc/${REGISTRY_IP}/g" | \
      oc create -f - -n ${TGT_PROJECT}
    fi
  done
fi

# Deployments are needed to roll back to a previous image version.
# We don't export/import images, and cannot import builds (see above),
# so importing deployments would be pointless.

#for object in replicasets deployments
for object in replicasets
do
  [[ -f ${PROJECTPATH}/${object}.json ]] && \
    jq ".metadata.namespace = \"${TGT_PROJECT}\"" ${PROJECTPATH}/${object}.json | \
    sed -e "s/docker-registry.default.svc/${REGISTRY_IP}/g" | \
    oc create -f - -n ${TGT_PROJECT}
done

# Replication controllers are created by deployment controllers.
# Importing the original replication controllers would not work
# because they reference specific images that the target namespace
# does not have access to.

#if compgen -G "${PROJECTPATH}/rc_*.json" >/dev/null; then
#  for rc in ${PROJECTPATH}/rc_*.json
#  do
#    rcfile=$(echo ${rc##*/})
#    RCNAME=$(echo ${rcfile} | sed "s/rc_\(.*\)\.json$/\1/")
#    echo "Checking ${RCNAME}"
#    if ! oc get rc ${RCNAME} -n ${TGT_PROJECT} >/dev/null 2>&1; then
#      oc create -f ${rc} -n ${TGT_PROJECT} 
#    fi
#  done
#fi

#for object in pods cronjobs statefulsets daemonset
for object in cronjobs statefulsets daemonset
do
  [[ -f ${PROJECTPATH}/${object}.json ]] && \
    jq ".metadata.namespace = \"${TGT_PROJECT}\"" ${PROJECTPATH}/${object}.json | \
    sed -e "s/docker-registry.default.svc/${REGISTRY_IP}/g" | \
    oc create -f - -n ${TGT_PROJECT}
done

[[ -f ${PROJECTPATH}/pvcs_attachment.json ]] &&
  echo "There are pvcs objects with attachment information included in the ${PROJECTPATH}/pvcs_attachment.json file, remove the current pvcs and restore them using that file if required"

IMAGE_DIR=$(readlink -f ${PROJECTPATH}/../images)

cd /usr/local/backup-restore-projects

ansible-playbook \
  -e project_name=${TGT_PROJECT} \
  -e image_dir=${IMAGE_DIR} \
  restore-images.yml
