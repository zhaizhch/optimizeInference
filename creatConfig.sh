server=https://10.96.0.1:443
name=test-token-v4s67
namespace=video-test
 
 
ca=$(kubectl get secret/$name -n $namespace -o jsonpath='{.data.ca\.crt}')
token=$(kubectl get secret/$name -n $namespace -o jsonpath='{.data.token}' | base64 --decode)
 
 
echo "apiVersion: v1
kind: Config
clusters:
- name: test
  cluster:
    certificate-authority-data: ${ca}
    server: ${server}
contexts:
- name: test
  context:
    cluster: test
    user: test
current-context: test
users:
- name: test
  user:
    token: ${token}
" > video-test.kubeconfig
