# Доработки к диплому

## Установка Ingress 
Сначала попробовал вот так
```
nano values.yaml

controller:
  service:
    type: NodePort
    loadBalancerIP: 51.250.47.143"
    nodePorts:
      http: 30080
  config:
    pid: "/tmp/nginx/ingress_nginx.pid"
```

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace -f ./values.yaml
```
После сделал по-другому
```
helm upgrade --install ingress-nginx ingress-nginx \
--repo https://kubernetes.github.io/ingress-nginx \
--namespace ingress-nginx --create-namespace
```
В некоторых случаях может понадобиться, грубо говоря [пропатчить](https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-helm/)
```
helm pull oci://ghcr.io/nginxinc/charts/nginx-ingress --untar --version 1.1.2 && \
cd nginx-ingress && \
kubectl apply -f crds/
```
```
kubectl apply -f externalIP.yaml

nano externalIP.yaml

apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.8.2
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  externalTrafficPolicy: Local
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  ports:
    - appProtocol: http
      name: http
      port: 80
      protocol: TCP
      targetPort: http
    - appProtocol: https
      name: https
      port: 443
      protocol: TCP
      targetPort: https
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  type: LoadBalancer
  externalIPs:
    - 51.250.47.143
```
                             
                                                                  
