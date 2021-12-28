# optimizeInference
 对推理平台进行优化

1.PYTHON实现k8s通过认证的两种方式

1>**HTTPS证书认证（kubeconfig）：**

\# 默认使用： cat ./kube/config

```python
from kubernetes import client, config
 import os
 kubeconfig = os.path.join(os.getcwd(),"kubeconfig") # 获取当前目录并拼接文件
 config.load_kube_config(kubeconfig) # 指定kubeconfig配置文件（/root/.kube/config）
 apps_api = client.AppsV1Api() # 资源接口类实例化

\#通过 kubectl api-resources | grep deploy 判断是哪个资源接口

for dp in apps_api.list_deployment_for_all_namespaces().items:
   print(dp) # 打印Deployment对象详细信息
```

2>**HTTP Token认证（ServiceAccount）：**

```python
from kubernetes import client
 import os
 configuration = client.Configuration()
 configuration.host = " https://192.168.31.61:6443" # APISERVER地址
 ca_file = os.path.join(os.getcwd(),"ca.crt") # K8s集群CA证书（/etc/kubernetes/pki/ca.crt）
 configuration.ssl_ca_cert= ca_file
 configuration.verify_ssl = True  # 启用证书验证，启用的话 要指定ca_file 的配置
 token = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImdlQlFUM3..." # 指定Token字符串，下面方式获取
 configuration.api_key = {"authorization": "Bearer " + token} # Bearer后的空格不能少
 client.Configuration.set_default(configuration)
 apps_api = client.AppsV1Api() 

for dp in apps_api.list_deployment_for_all_namespaces().items:
   print(dp)
```

其中configuration.host的获取方式：

os.getenv("KUBERNETES_SERVICE_HOST")

os.getenv("KUBERNETES_SERVICE_PORT")

token的所在位置：pod容器内"/var/run/secrets/kubernetes.io/serviceaccount/token"

**go语言实现方式**

**go****语言实现权限认证**

 

```go
func**InClusterConfig()(*Config,**error**){

**const**(

tokenFile="/var/run/secrets/kubernetes.io/serviceaccount/token"

rootCAFile="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

)

host,port:=os.Getenv("KUBERNETES_SERVICE_HOST"),os.Getenv("KUBERNETES_SERVICE_PORT")

**if**len(host)==**0**||len(port)==**0**{

**return**nil,ErrNotInCluster

}

token,err:=ioutil.ReadFile(tokenFile)

**if**err!=nil{

**return**nil,err

}

tlsClientConfig:=TLSClientConfig{}

**if**_,err:=certutil.NewPool(rootCAFile);err!=nil{

klog.Errorf("Expected to load root CA config from %s, but got err: %v",rootCAFile,err)

}**else**{

tlsClientConfig.CAFile=rootCAFile

}

**return**&Config{

// TODO: switch to using cluster DNS.

Host:"https://"+net.JoinHostPort(host,port),

TLSClientConfig:tlsClientConfig,

BearerToken:**string**(token),

BearerTokenFile:tokenFile,

},nil

}
```

**RBAC**全称Role-Based Access Control，是Kubernetes集群基于角色的访问控制，实现授权决策，允许通过Kubernetes API动态配置策略。

**角色**

一个角色就是一组权限的集合，这里的权限都是许可形式的，不存在拒绝的规则。

角色只能对命名空间内的资源进行授权 

Role：授权特定命名空间的访问权限【 在一个命名空间中，可以用角色来定义一个角色】 

ClusterRole：授权所有命名空间的访问权限【如果是集群级别的，就需要使用ClusterRole了。】 

角色绑定 

RoleBinding：将角色绑定到主体（即subject）【对应角色的Role】 

ClusterRoleBinding：将集群角色绑定到主体【对应角色的ClusterRole】 

**主体（subject）** 

User：用户

Group：用户组

ServiceAccount：服务账号

用户或者用户组，服务账号，与具备某些权限的角色绑定，然后将该角色的权限继承过来，这一点类似阿里云的 ram 授权。这里需要注意 定义的角色是 Role作用域只能在指定的名称空间下有效，如果是ClusterRole可作用于所有名称空间下。





**ClusterRole和Role的参数值说明**

可以配置多组apiGroups实现对不同资源的不同权限

1、apiGroups可配置参数

这个很重要，是父子级的关系【kubectl api-versions 可以查看】【一般有2种格式 /xx 和xx/yy】

“”,“apps”, “autoscaling”, “batch”

2、resources可配置参数

“services”， “endpoints”，“pods”，“secrets”，“configmaps”，“crontabs”，“deployments”，“jobs”，“nodes”，“rolebindings”，“clusterroles”，“daemonsets”，“replicasets”，“statefulsets”，“horizontalpodautoscalers”，“replicationcontrollers”，“cronjobs”

3、verbs可配置参数

“get”，“list”，“watch”， “create”，“update”， “patch”， “delete”，“exec”



生成role的yaml文件：

  -   - ```yaml
      kind: Role
      apiVersion: rbac.authorization.k8s.io/v1
      metadata:
        name: test
        namespace: video-test
      rules:
      
        - apiGroups: ["", "extensions", "apps"]
          resources: ["*"]
          verbs: ["*"]
        - apiGroups: ["batch"]
          resources:
            - jobs
            - cronjobs
              verbs: ["*"]
      ```

创建serviceAccount的yaml文件：

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test
  namespace: video-test
```

将角色和账号绑定的yaml文件：

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: test
  namespace: video-test
subjects:
  - kind: ServiceAccount
    name: test
    namespace: video-test
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: test
```

```yaml
kind: ClusterRoleBinding

apiVersion: rbac.authorization.k8s.io/v1

metadata:

 name: read-secrets-global

subjects:

 - kind: Group

 name: manager

 apiGroup: rbac.authorization.k8s.io

roleRef:

 kind: ClusterRole

 name: secret-reader

 apiGroup: rbac.authorization.k8s.io
```

rolebinding可以与clsterrole组合，这样还是只能拥有一个namespace下权限，namespace由rolebinding中的metadata.namespace确定，相当于为所有的命名空间确定相同的权限的一个模板；但是clusterrolebinding不能与role相结合；当clusterrolebinding与clusterrole结合时，这是这个serviceAccount的权限对所有的命名空间都有效。

RoleBinding也可以引用ClusterRole，对属于同一命名空间内ClusterRole定义的资源主体进行授权。一种常见的做法是集群管理员为集群范围预先定义好一组角色(ClusterRole)，然后在多个命名空间中重复使用这些ClusterRole。

**kubectl指令方式实现上述内容：**

```shell
\# 鉴权命令：

kubectl auth can-i create deployments --namespace video-test --as system:serviceaccount:video-test:default

 

\# 创建用户
 kubectl create serviceaccount dashboard-admin -n kube-system
 \# 用户授权
 kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
 \# 获取用户Token
 kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
```

**将token生成yml文件** 

1. ```shell
    server=https://your-server:443
    name=postgresql-token-v26k7
    namespace=postgresql
    ca=$(kubectl get     secret/$name -n $namespace -o jsonpath='{.data.ca\.crt}')
    token=$(kubectl get     secret/$name -n $namespace -o jsonpath='{.data.token}' | base64 --decode)
    echo     "apiVersion: v1
    kind: Config
    clusters:
   \- name: test
    cluster:
    certificate-authority-data:     ${ca}
    server: ${server}
    contexts:
    \- name: test
    context:
    cluster: test
    user: postgresql
    current-context:     test
    users:
    \- name: postgresql
    user:
    token: ${token}
    " >     postgresql.kubeconfig
   ```

   

•server：就是 Kubernetes Server API 的地址•name：就是 ServiceAccount 对应的 secret•namespace：就是当前操作的 Namespace

运行之后就会生成一个 portgresql.kubeconfig 文件。name通过下述命令获得: kubectl get serviceaccount postgresql -n postgresql -o yaml

 **config文件使用方式**

export KUBECONFIG=postgresql.kubeconfig

这里我们就将 KUBECONFIG 设置了下，这样再执行 kubectl 就会读取到当前的 kubeconfig 文件，就会生效了。



RBAC(Role-Based Access Control，基于角色的访问控制)，允许通过Kubernetes API动态配置策略。

在k8s v1.5中引入，在v1.6版本时升级为Beta版本，并成为kubeadm安装方式下的默认选项，相对于其他访问控制方式，新的**RBAC具有如下优势：**

对集群中的资源和非资源权限均有完整的覆盖

整个RBAC完全由几个API对象完成，同其他API对象一样，可以用kubectl或API进行操作

可以在运行时进行调整，无需重启API Server

要使用RBAC授权模式，需要在API Server的启动参数中加上–authorization-mode=RBAC

- 配置文件：/etc/kubernetes/manifests/kube-apiserver.yaml
            这个里面配置授权规则，大概在20行，规则有如下几项
            修改规则以后需要重启服务生效：systemctl restart kubelet







**curl测试token是否有效**

 [root@docker176 net.d]# 

```shell
curl -k -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJjYWxpY28tY25pLXBsdWdpbi10b2tlbi14N3dsMiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJjYWxpY28tY25pLXBsdWdpbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjEyYWQyMjI5LTVkMWYtMTFlOS05ZGYzLTAwMGMyOTM4ODYyYyIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTpjYWxpY28tY25pLXBsdWdpbiJ9.VtyfKi39LKcx8Piy0x0cfa5bUxkEn1BhMYzAn_3BaZTma_nOjTMCrAHdqR1wCidH9__U43nKWRhM8qpBhc2OPp30VGFdMt25oJcCF5jcZKzbxvPt0HXKOgOeTctwgatnwsfEBtVarM1V_l9fQswinZbUHSjCCnYsVd1HMoeBOE6Gtxa14kz68wcbK9RFTHrxgo5cdtXxO7JFKRmR5GpmL0Xa2KjuWvY8H-6jSNVv-b-o5SjurV6Ha7Zysibpb8gLr86-QacMPnwP56Y9rBgxmGymUMXTJjXTXmKTY3G_Ha-CXk4Phrf9x58jVu48IHEFhzlnn6m_Kw6nGNEs-32IYw' https://10.254.0.1:443/api

```

   返回结果：

```shell
{

"kind": "APIVersions",

   "versions": [

​    "v1"

   ],

   "serverAddressByClientCIDRs": [

​    {

​     "clientCIDR": "0.0.0.0/0",

​     "serverAddress": "192.168.14.176:6443"

​    }

   ]
```





获取token并转码的方式

```
1.查看所有账号：

kubectl -n kube-system get sa

2.取secrets：

kubectl -n kube-system get sa default -o yaml

3.查token：

kubetcl get secrets default-token-rqfc5 -n kube-system -oyaml

取具体token值：

kubectl get secrets default-token-rqfc5 -n kube-system -o jsonpath={".data.token"}

4.token转码：

kubectl get secrets default-token-rqfc5 -n kube-system -o jsonpath={".data.token"} | base64 -d
```

```
kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
```





