# Доработки к диплому

## Установка Ingress 
```
helm upgrade --install ingress-nginx ingress-nginx \
--repo https://kubernetes.github.io/ingress-nginx \
--namespace ingress-nginx --create-namespace
```
Возможно придется ["патчить"](https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-helm/)  
```
helm pull oci://ghcr.io/nginxinc/charts/nginx-ingress --untar --version 1.1.2 && \
cd nginx-ingress && \
kubectl apply -f crds/
```
Выполняем
```
KUBE_EDITOR="nano" kubectl edit configmap -n kube-system kube-proxy
```
Пропишем
```
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```
```
kubectl apply -f externalIP.yaml

cat externalIP.yaml

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
    - 51.250.32.236
```
```
 kubectl -n ingress-nginx get svc
NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.233.37.254   51.250.32.236   80:30539/TCP,443:31787/TCP   3m33s
ingress-nginx-controller-admission   ClusterIP      10.233.56.27    <none>          443/TCP                      10m
```
![](https://github.com/networksuperman/devops-diplom-yandexcloud/blob/main/images/ingress-main-1.png)  

![](https://github.com/networksuperman/devops-diplom-yandexcloud/blob/main/images/ingress-main-2.png)  

Создадим простой Ingress
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  rules:
  - host: 
    http:
      paths:
      - path: /grafana
        pathType: Prefix
        backend:
          service:
            name: grafana-service
            port:
              number: 3000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: diploma-service
            port:
              number: 80
```
```
kubectl apply -f ingress.yaml
```
Оба приложения теперь доступны по одному ip адресу 51.250.32.236, на 3000 и 80 портах

![](https://github.com/networksuperman/devops-diplom-yandexcloud/blob/main/images/ingress-main-3.png)  

![](https://github.com/networksuperman/devops-diplom-yandexcloud/blob/main/images/ingress-main-4.png)  

