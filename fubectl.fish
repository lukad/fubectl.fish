set openCmd (
    switch (uname)
    case Darwin
        echo 'open'
    case '*'
        echo 'xdg-open'
    end
)


alias k='kubectl'
alias kw='watch kubectl get'
alias ka='kubectl get pods'
alias kall='kubectl get pods --all-namespaces'
alias kwall='watch kubectl get pods --all-namespaces'
alias kp="$openCmd 'http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/' & kubectl proxy"
alias _inline_fzf="fzf --multi --ansi -i -1 --height=50% --reverse -0 --header-lines=1 --inline-info --border"
alias _inline_fzf_nh="fzf --multi --ansi -i -1 --height=50% --reverse -0 --inline-info --border"
function _isClusterSpaceObject --argument obj
    # caller is responsible for assuring non-empty "$1"
    kubectl api-resources --namespaced=false \
        | awk '(apiidx){print substr($0, 0, apiidx),substr($0, kindidx) } (!apiidx){ apiidx=index($0, " APIVERSION");kindidx=index($0, " KIND")}' \
        | grep -iq "\<$obj\>"
end

# [kwatchn] watch a resource of KIND in current namespace, usage: kwatchn [KIND] - if KIND is empty then pod is used
function kwatchn --wraps 'watch kubectl get' --argument kind
    set -q kind[1]; or set kind pod
    set rest $argv[2..-1]
    kubectl get $kind $rest | _inline_fzf | awk '{print $1}' | xargs -r watch kubectl get $kind $rest
end

# [kcmd] create a pod from IMAGE (ubuntu by default) and execute CMD (bash by default), usage: kcmd [CMD] [IMAGE]
function kcmd --wraps '' --argument cmd image
    set -q cmd[1]; and set cmd -c $cmd
    set -q image[1]; or set image ubuntu
    set ns (kubectl get ns | _inline_fzf | awk '{print $1}')

    kubectl run shell-(random) --namespace $ns --rm -i --tty --image $image -- /bin/bash $cmd
end

function kget --wraps 'kubectl get' --argument kind
    set -q kind[1]; or set kind pod
    if _isClusterSpaceObject $kind
        kubectl get $kind | _inline_fzf | awk '{print $1}' | xargs -r watch kubectl get $kind
    else
        kubectl get $kind --all-namespaces | _inline_fzf | awk '{print $1}' | xargs -r watch kubectl get $kind -n
    end
end

# [kube_ctx_name] get the current context
alias kube_ctx_name="kubectl config current-context"

# [kube_ctx_namespace] get current namespace
function kube_ctx_namespace
    set default_ns (kubectl config view --minify | grep namespace: | sed 's/namespace: //g' | tr -d ' ')
    test -z $default_ns; and set default_ns default
    echo $default_ns
end

# [kgetn] get resource of KIND from current namespace, usage: kgetn [KIND] - if KIND is empty then pod is used
function kgetn --argument kind
    set -q kind[1]; or set kind pod
    kubectl get $kind | _inline_fzf | awk '{print $1}' | xargs -r kubectl get -o yaml "$kind"
end

# [kget] get resource of KIND from cluster, usage: kget [KIND] - if KIND is empty then pod is used
function kget --argument kind
    set -q kind[1]; or set kind pod
    if _isClusterSpaceObject "$kind"
        kubectl get $kind | _inline_fzf | awk '{print $1}' | xargs -r kubectl get -o yaml $kind
    else
        kubectl get $kind --all-namespaces | _inline_fzf | awk '{print $1, $2}' | xargs -r kubectl get -o yaml $kind -n
    end
end

# [kexp] as former `--export` field removes unwanted metadata - usage: COMMAND | kexp
function kexp
    if [ -t 0 ]
        echo "kexp has no piped input!"
        echo "usage: COMMAND | kexp"
    else
        # remove not neat fields
        kubectl neat
    end
end

# [kget-exp] get a resource by its YAML as former `--export` flag
function kget-exp
    kget $argv | kexp
end

# [kedn] edit resource of KIND from current namespace, usage: kedn [KIND] - if KIND is empty then pod is used
function kedn --argument kind
    set -q kind[1]; or set kind pod
    set object (kubectl get $kind | _inline_fzf | awk '{print $1}')
    kubectl edit $kind $object
end

# [ked] edit resource of KIND from cluster, usage: ked [KIND] - if KIND is empty then pod is used
function ked --argument kind
    set -q kind[1]; or set kind pod
    if _isClusterSpaceObject $kind
        set edit_args (kubectl get $kind | _inline_fzf | awk '{print $1}')
    else
        set edit_args (kubectl get $kind --all-namespaces | _inline_fzf | awk '{print "-n", $1, $2}')
    end
    echo kubectl edit $kind $edit_args
end

# [kdesn] describe resource of KIND in current namespace, usage: kdesn [KIND] - if KIND is empty then pod is used
function kdesn --argument kind
    set -q kind[1]; or set kind pod
    kubectl get $kind | _inline_fzf | awk '{print $1}' | xargs -r kubectl describe $kind
end

# [kdes] describe resource of KIND in cluster, usage: kdes [KIND] - if KIND is empty then pod is used
function kdes --argument kind
    set -q kind[1]; or set kind pod
    if _isClusterSpaceObject $kind
        kubectl get $kind | _inline_fzf | awk '{print $1}' | xargs -r kubectl describe $kind
    else
        kubectl get $kind --all-namespaces | _inline_fzf | awk '{print $1, $2}' | xargs -r kubectl describe $kind -n
    end
end

# [kdeln] delete resource of KIND in current namespace, usage: kdeln [KIND] - if KIND is empty then pod is used
function kdeln --argument kind
    set -q kind[1]; or set kind pod
    kubectl get $kind | _inline_fzf | awk '{print $1}' | xargs -r -p kubectl delete $kind
end

# [kdel] delete resource of KIND in cluster, usage: kdel [KIND] - if KIND is empty then pod is used
function kdel --argument kind
    set -q kind[1]; or set kind pod
    if _isClusterSpaceObject "$kind"
        kubectl get $kind | _inline_fzf | awk '{print $1}' | xargs -r -p kubectl delete $kind
    else
        kubectl get $kind --all-namespaces | _inline_fzf | awk '{print $1, $2}' | xargs -r -p kubectl delete $kind -n
    end
end

# [klog] fetch log from container
function _klog_usage
    echo "Usage: klog [LINECOUNT] [options]

First argument is interpreted as LINECOUNT if it matches integer syntax.
Additional `options` are passed on (see `kubectl logs --help` for details)."
end

function klog
    [ $argv[1] = --help ]; and _klog_usage; and return
    set line_count 10
    # if [[ $1 =~ ^[-]{0,1}[0-9]+$ ]]
    #     set line_count $argv[1]
    # end

    set arg_pair (kubectl get po --all-namespaces | _inline_fzf | awk '{print $1, $2}')
    test -z $arg_pair; and printf "klog: no pods found. no logs can be shown.\n"; and return
    set containers_out (echo $arg_pair | xargs kubectl get po -o=jsonpath='{.spec.containers[*].name} {.spec.initContainers[*].name}' -n | sed 's/ $//')
    # local container_choosen=$(echo "$containers_out" |  tr ' ' "\n" | _inline_fzf_nh)
    # _kctl_tty logs -n ${arg_pair} -c "${container_choosen}" --tail="${line_count}" "$@"
end

# # [kkonfig] select a file in current directory and set it as $KUBECONFIG
# kkonfig() {
#     local kubeconfig
#     kubeconfig=$(_inline_fzf_nh) || return
#     export KUBECONFIG=$PWD/$kubeconfig
#     exec $SHELL
# }

# # [kexn] execute command in container from current namespace, usage: kexn CMD [ARGS]
# kexn() {
#     [ -z "$1" ] && printf "kexn: missing argument(s).\nUsage: kexn CMD [ARGS]\n" && return 255
#     local arg_pair=$(kubectl get po | _inline_fzf | awk '{print $1, $2}')
#     [ -z "$arg_pair" ] && printf "kex: no pods found. no execution.\n" && return
#     local containers_out=$(echo "$arg_pair" | xargs kubectl get po -o=jsonpath='{.spec.containers[*].name}' -n)
#     local container_choosen=$(echo "$containers_out" |  tr ' ' "\n" | _inline_fzf_nh)
#     _kctl_tty exec -it -n ${arg_pair} -c "${container_choosen}" -- "$@"
# }

# [kex] execute command in container from cluster, usage: kex CMD [ARGS]
function kex --argument-names cmd
    if set -q $cmd[1]
        printf "kex: missing argument(s).\nUsage kex CMD [ARGS]"
        return 255
    end
    # we have to split here, otherwise kubectl interprets this as one argument
    set -l arg_pair $(kubectl get po --all-namespaces | _inline_fzf | awk '{print $1, $2}' | string split ' ')
    if set -q $arg_pair
        printf "key: no pods found. No execution.\n"
        return 255
    end
    set -l containers_out $(echo "$arg_pair" | xargs kubectl get po -o=jsonpath='{.spec.containers[*].name} ' -n)
    set -l container_choosen $(echo "$containers_out" | tr ' ' "\n" | _inline_fzf_nh)
    kubectl exec -it -n "$arg_pair[1]" $arg_pair[2] -c "$container_choosen[1]" -- "$cmd[1..]"
end

# # [kforn] port-forward a container port from current namesapce, usage: kforn LOCAL_PORT:CONTAINER_PORT
# kforn() {
#     local port="$1"
#     [ -z "$port" ] && printf "kforn: missing argument.\nUsage: kforn LOCAL_PORT:CONTAINER_PORT\n" && return 255
#     local arg_pair="$(kubectl get po | _inline_fzf | awk '{print $1, $2}')"
#     [ -z "$arg_pair" ] && printf "kforn: no pods found. no forwarding.\n" && return
#     _kctl_tty port-forward -n $arg_pair "$port"
# }

# # [kfor] port-forward a container port from cluster, usage: kfor LOCAL_PORT:CONTAINER_PORT
# kfor() {
#     local port="$1"
#     [ -z "$port" ] && printf "kfor: missing argument.\nUsage: kfor LOCAL_PORT:CONTAINER_PORT\n" && return 255
#     local arg_pair="$(kubectl get po --all-namespaces | _inline_fzf | awk '{print $1, $2}')"
#     [ -z "$arg_pair" ] && printf "kfor: no pods found. no forwarding.\n" && return
#     _kctl_tty port-forward -n $arg_pair "$port"
# }

# # [ksearch] search for string in resources
# ksearch() {
#     local search_query="$1"
#     [ -z "$search_query" ] && printf "ksearch: missing argument.\nUsage: ksearch SEARCH_QUERY\n" && return 255
#     for ns in $(kubectl get --export -o=json ns | jq -r '.items[] | .metadata.name'); do
#         kubectl --namespace="${ns}" get --export -o=json \
#             deployment,ingress,daemonset,secrets,configmap,service,serviceaccount,statefulsets,pod,endpoints,customresourcedefinition,events,networkpolicies,persistentvolumeclaims,persistentvolumes,replicasets,replicationcontrollers,statefulsets,storageclasses | \
#         jq '.items[]' -c | \
#         grep "$search_query" | \
#         jq -r  '. | [.kind, .metadata.name] | @tsv' | \
#         awk -v prefix="$ns" '{print "kubectl get -n " prefix " " $0}'
#     done
# }

# [kcl] context list
alias kcl='kubectl config get-contexts'

# kcs() {
#     local context="$(kubectl config get-contexts | _inline_fzf | cut -b4- | awk '{print $1}')"
#     kubectl config set current-context "${context}"
# }
# [kcs] context set
function kcs
    set -l context (kubectl config get-contexts | _inline_fzf | cut -b4- | awk '{print $1}')
    kubectl config set current-context $context
end



# # [kcns] context set default namespace
# kcns() {
#     local ns="$1"
#     if [ -z "$ns" ]; then
#         ns="$(kubectl get ns | _inline_fzf | awk '{print $1}')"
#     fi
#     [ -z "$ns" ] && printf "kcns: no namespace selected/found.\nUsage: kcns [NAMESPACE]\n" && return
#     kubectl config set-context "$(kubectl config current-context)" --namespace="${ns}"
# }

# # [kwns] watch pods in a namespace
# kwns() {
#     local ns=$(kubectl get ns | _inline_fzf | awk '{print $1}')
#     [ -z "$ns" ] && printf "kcns: no namespace selected/found.\nUsage: kwns\n" && return
#     watch kubectl get pod -n "$ns"
# }

# # [ktreen] prints a tree of k8s objects from current namespace, usage: ktreen [KIND]
# ktreen() {
#     local kind="$1"
#     if [ -z "$kind" ]; then
#         local kind="$(kubectl api-resources -o name | _inline_fzf | awk '{print $1}')"
#     fi
#     kubectl get "$kind" | _inline_fzf | awk '{print $1}' | xargs -r kubectl tree "$kind"
# }

# # [ktree] prints a tree of k8s objects from cluster, usage: ktree [KIND]
# ktree() {
#     local kind="$1"
#     if [ -z "$kind" ]; then
#         local kind="$(kubectl api-resources -o name | _inline_fzf | awk '{print $1}')"
#     fi
#     if _isClusterSpaceObject "$kind" ; then
#         kubectl get "$kind" | _inline_fzf | awk '{print $1}' | xargs -r kubectl tree "$kind"
#     else
#         kubectl get "$kind" --all-namespaces | _inline_fzf | awk '{print $1, $2}' | xargs -r kubectl tree "$kind" -n
#     fi
# }

# # [konsole] create root shell on a node
# konsole() {
#     local node_hostname="$(kubectl get node --label-columns=kubernetes.io/hostname | _inline_fzf | awk '{print $6}')"
#     local ns="$(kubectl get ns | _inline_fzf | awk '{print $1}')"
#     local name=shell-$RANDOM
#     local overrides='
# {
#     "spec": {
#         "hostPID": true,
#         "hostNetwork": true,
#         "tolerations": [
#             {
#                 "operator": "Exists",
#                 "effect": "NoSchedule"
#             },
#             {
#                 "operator": "Exists",
#                 "effect": "NoExecute"
#             }
#         ],
#         "containers": [
#             {
#                 "name": "'$name'",
#                 "image": "alpine",
#                 "command": [
#                     "/bin/sh"
#                 ],
#                 "args": [
#                     "-c",
#                     "nsenter -t 1 -m -u -i -n -p -- bash"
#                 ],
#                 "resources": null,
#                 "stdin": true,
#                 "stdinOnce": true,
#                 "terminationMessagePath": "/dev/termination-log",
#                 "terminationMessagePolicy": "File",
#                 "tty": true,
#                 "securityContext": {
#                     "privileged": true
#                 }
#             }
#         ],
#         "nodeSelector": {
#             "kubernetes.io/hostname": "'$node_hostname'"
#         }
#     }
# }
# '
#     kubectl run $name --namespace "$ns" --rm -it --image alpine --overrides="${overrides}"
# }

# # [ksecn] decode a value from a secret in current namespace, usage: ksecn
# ksecn() {
#     local secret=$(kubectl get secret | _inline_fzf | awk '{print $1}')
#     local key=$(kubectl get secret "${secret}" -o go-template='{{- range $k,$v := .data -}}{{- printf "%s\n" $k -}}{{- end -}}' | _inline_fzf_nh)
#     kubectl get secret "${secret}" -o go-template='{{ index .data "'$key'" | base64decode }}'
# }

# # [ksec] decode a value from a secret in cluster, usage: ksec
# ksec() {
#     local ns=$(kubectl get ns | _inline_fzf | awk '{print $1}')
#     local secret=$(kubectl get secret -n "$ns" | _inline_fzf | awk '{print $1}')
#     local key=$(kubectl get secret -n "$ns" "$secret" -o go-template='{{- range $k,$v := .data -}}{{- printf "%s\n" $k -}}{{- end -}}' | _inline_fzf_nh)
#     kubectl get secret -n "$ns" "${secret}" -o go-template='{{ index .data "'$key'" | base64decode }}'
# }

# # [kinstall] Install the required kubectl plugins
# kinstall() {
#     kubectl krew install tree
#     kubectl krew install neat
# }
# # [kupdate] Updates kubectl plugins
# kupdate() {
#     kubectl krew upgrade
# }

# #### Kubermatic KKP specific
# # [kkp-cluster] Kubermatic KKP - extracts kubeconfig of user cluster and connects it in a new bash
# kkp-cluster() {
#     TMP_KUBECONFIG=$(mktemp)
#     local cluster="$(kubectl get cluster | _inline_fzf | awk '{print $1}')"
#     kubectl get secret admin-kubeconfig -n cluster-$cluster -o go-template='{{ index .data "kubeconfig" | base64decode }}' > $TMP_KUBECONFIG
#     KUBECONFIG=$TMP_KUBECONFIG $SHELL
# }

# # [khelp] show this help message
# khelp() {
#     echo "Usage of fubectl"
#     echo
#     echo "Reduces repetitive interactions with kubectl"
#     echo "Find more information at https://github.com/kubermatic/fubectl"
#     echo
#     echo "Usage:"
#     if [ -n "$ZSH_VERSION" ]
#     then
#         grep -E '^# \[.+\]' "${(%):-%x}"
#     else
#         grep -E '^# \[.+\]' "${BASH_SOURCE[0]}"
#     fi
# }
