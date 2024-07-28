# Дипломный практикум в Yandex.Cloud
  * [Цели:](#цели)
  * [Этапы выполнения:](#этапы-выполнения)
     * [Создание облачной инфраструктуры](#создание-облачной-инфраструктуры)
     * [Создание Kubernetes кластера](#создание-kubernetes-кластера)
     * [Создание тестового приложения](#создание-тестового-приложения)
     * [Подготовка cистемы мониторинга и деплой приложения](#подготовка-cистемы-мониторинга-и-деплой-приложения)
     * [Установка и настройка CI/CD](#установка-и-настройка-cicd)
  * [Что необходимо для сдачи задания?](#что-необходимо-для-сдачи-задания)
  * [Как правильно задавать вопросы дипломному руководителю?](#как-правильно-задавать-вопросы-дипломному-руководителю)

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**

---
## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

---
## Этапы выполнения:

<details><summary>Создание облачной инфраструктуры</summary>

Обновим Terraform до последней версии

```
terraform version
Terraform v1.9.3
on linux_amd64
```

С помощью terraform создадим сервисный аккаунт и bucket для backend'a Terraform (хранение tfstate файлов)  

bucket.tf link  

Далее создадим VPC так, чтобы подсети были разнесены по разным зонам 
networks.tf link  

В результате работы terraform мы получаем master ноду и 3 worker
```
terraform apply
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.

Outputs:

external_ip_control_plane = "51.250.11.205"
external_ip_nodes = tolist([
  "89.169.138.220",
  "89.169.160.113",
  "51.250.36.217",
])
```

В kubespray/inventory/my-k8s-cluster мы получаем файл hosts.yml, который пригодится нам в дальнейшем дял установки кластера через kubespray
```
---
all:
  hosts:
    control-plane:
      ansible_host: 51.250.11.205
      ansible_user: ubuntu
    node-1:
      ansible_host: 89.169.138.220
      ansible_user: ubuntu
    node-2:
      ansible_host: 89.169.160.113
      ansible_user: ubuntu
    node-3:
      ansible_host: 51.250.36.217
      ansible_user: ubuntu
  children:
    kube_control_plane:
      hosts:
        control-plane:
    kube_node:
      hosts:
        node-1:
        node-2:
        node-3:
    etcd:
      hosts:
        control-plane:
    k8s_cluster:
      vars:
        supplementary_addresses_in_ssl_keys: [51.250.11.205]
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
```
</details>
  
<details><summary>Создание Kubernetes кластера</summary>

Теперь создадим k8s кластер, для этого воспользуемся kubespray
```
git clone https://github.com/kubernetes-sigs/kubespray // клонируем репозиторий

sudo pip3 install -r requirements.txt // устанавливаем зависимости
```
На основе inventory hosts, сгенерированного с помощью terraform на предыдущем этапе, запустим ansible playbook
```
ansible-playbook -i inventory/my-k8s-cluster/hosts.yml --become --become-user=root cluster.yml
```
Подождем пока он закончит установку и после окончания скопируем с master ноды файл /etc/kubernetes/admin.conf на нашу локальную машину.
ВАЖНО - в файле необходимо заменить server ip на внешний ip адрес нашей master ноды
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQ
    server: https://51.250.11.205:6443
  name: cluster.local
contexts:
- context:
    cluster: cluster.local
    user: kubernetes-admin
  name: kubernetes-admin@cluster.local
current-context: kubernetes-admin@cluster.local
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURLVENDQWhHZ0F3SUJBZ0lJY3k4ZjZwSjlldk13R
    client-key-data: 0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb2dJQkFBS0NBUUVBelBlWVcwa3VocEVYdzlDSXAxd1V
```
Далее проверим наш кластер
```
kubectl get nodes
NAME            STATUS   ROLES           AGE     VERSION
control-plane   Ready    control-plane   7h18m   v1.30.3
node-1          Ready    <none>          7h17m   v1.30.3
node-2          Ready    <none>          7h17m   v1.30.3
node-3          Ready    <none>          7h17m   v1.30.3
```
```
kubectl get pods --all-namespaces
NAMESPACE     NAME                                                     READY   STATUS    RESTARTS        AGE
default       alertmanager-prometheus-stack-kube-prom-alertmanager-0   2/2     Running   0               6h24m
default       diploma-69d9948f7f-q7649                                 1/1     Running   0               118m
default       diploma-69d9948f7f-tt4rj                                 1/1     Running   0               118m
default       diploma-69d9948f7f-zv4tx                                 1/1     Running   0               118m
default       prometheus-prometheus-stack-kube-prom-prometheus-0       2/2     Running   0               6h24m
default       prometheus-stack-grafana-54b97b5955-pb54l                3/3     Running   0               6h25m
default       prometheus-stack-kube-prom-operator-6fd5b7d8c5-pnzfb     1/1     Running   0               6h25m
default       prometheus-stack-kube-state-metrics-7f9d94c768-5nw9r     1/1     Running   0               6h25m
default       prometheus-stack-prometheus-node-exporter-8gh8r          1/1     Running   0               6h25m
default       prometheus-stack-prometheus-node-exporter-9hwpg          1/1     Running   0               6h25m
default       prometheus-stack-prometheus-node-exporter-d66cz          1/1     Running   0               6h25m
default       prometheus-stack-prometheus-node-exporter-t692s          1/1     Running   0               6h25m
kube-system   calico-kube-controllers-c7cc688f8-chxrl                  1/1     Running   0               7h16m
kube-system   calico-node-pf8rl                                        1/1     Running   0               7h17m
kube-system   calico-node-qwbnk                                        1/1     Running   0               7h17m
kube-system   calico-node-tjqdv                                        1/1     Running   0               7h17m
kube-system   calico-node-wmclj                                        1/1     Running   0               7h17m
kube-system   coredns-776bb9db5d-ftb8w                                 1/1     Running   0               7h15m
kube-system   coredns-776bb9db5d-qcv96                                 1/1     Running   0               7h15m
kube-system   dns-autoscaler-6ffb84bd6-krsfb                           1/1     Running   0               7h15m
kube-system   kube-apiserver-control-plane                             1/1     Running   2 (7h14m ago)   7h19m
kube-system   kube-controller-manager-control-plane                    1/1     Running   3 (7h14m ago)   7h19m
kube-system   kube-proxy-6lgvl                                         1/1     Running   0               7h18m
kube-system   kube-proxy-rcbdb                                         1/1     Running   0               7h18m
kube-system   kube-proxy-tblp7                                         1/1     Running   0               7h18m
kube-system   kube-proxy-x9mtm                                         1/1     Running   0               7h18m
kube-system   kube-scheduler-control-plane                             1/1     Running   2 (7h14m ago)   7h19m
kube-system   nginx-proxy-node-1                                       1/1     Running   0               7h18m
kube-system   nginx-proxy-node-2                                       1/1     Running   0               7h18m
kube-system   nginx-proxy-node-3                                       1/1     Running   0               7h18m
kube-system   nodelocaldns-64zqb                                       1/1     Running   0               7h15m
kube-system   nodelocaldns-hscxm                                       1/1     Running   0               7h15m
kube-system   nodelocaldns-ljhh4                                       1/1     Running   0               7h15m
kube-system   nodelocaldns-m6ff2                                       1/1     Running   0               7h15m
```
</details>

  
<details><summary>Создание тестового приложения</summary>
На основе nginx, создадим docker image, который будет имитировать работу нашего приложения  
Выберем DockerHub как регистри

Repository link

Dockerfile link

nginx conf link

![]()  image of docker registry

Для того чтобы развернуть наше приложение в k8s кластере, подготовим deployment и service файлы
```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: diploma
spec:
  replicas: 3
  selector:
    matchLabels:
      app: diploma
  template:
    metadata:
      labels:
        app: diploma
    spec:
      containers:
        - name: diploma
          image: networkdockering/diploma:{{image_tag}}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
```
```
---
apiVersion: v1
kind: Service
metadata:
  name: diploma-svc
spec:
  type: NodePort
  selector:
    app: diploma
  ports:
    - name: web
      nodePort: 30903
      port: 80
      targetPort: 80
```
Для нашего приложения, в terraform, опишем network balancer
```
resource "yandex_lb_network_load_balancer" "nlb-my-k8s-app" {

  name = "nlb-my-k8s-app"

  listener {
    name        = "app-listener"
    port        = 80
    target_port = 30903
    external_address_spec {
      ip_version = "ipv4"
    }
  }
```
</details>

  
<details><summary>Подготовка cистемы мониторинга и деплой приложения</summary>

Развернем мониторинг с помощью Helm
```
helm version
version.BuildInfo{Version:"v3.15.3", GitCommit:"3bb50bbbdd9c946ba9989fbe4fb4104766302a64", GitTreeState:"clean", GoVersion:"go1.22.5"}
```
Для этого воспользуемся данным [чартом](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)  
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-stack  prometheus-community/kube-prometheus-stack
```
```
helm list
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
prometheus-stack        default         1               2024-07-28 06:50:17.37653586 +0000 UTC  deployed        kube-prometheus-stack-61.4.0    v0.75.2  
```
Для Grafana создадим NodePort service
```
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: grafana
  ports:
    - name: http
      nodePort: 30902
      port: 3000
      targetPort: 3000
```
С помощью terraform опишем network balancer для нашего приложения и Grafana, с целью получения доступа извне
```
resource "yandex_lb_target_group" "nlb-group-grafana" {

  name       = "nlb-group-grafana"
  depends_on = [yandex_compute_instance_group.k8s-node-group]

  dynamic "target" {
    for_each = yandex_compute_instance_group.k8s-node-group.instances
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "nlb-graf" {

  name = "nlb-grafana"

  listener {
    name        = "grafana-listener"
    port        = 3000
    target_port = 30902
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.nlb-group-grafana.id

    healthcheck {
      name = "healthcheck"
      tcp_options {
        port = 30902
      }
    }
  }
  depends_on = [yandex_lb_target_group.nlb-group-grafana]
}

resource "yandex_lb_network_load_balancer" "nlb-appl" {

  name = "nlb-my-k8s-app"

  listener {
    name        = "app-listener"
    port        = 80
    target_port = 30903
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.nlb-group-grafana.id

    healthcheck {
      name = "healthcheck"
      tcp_options {
        port = 30903
      }
    }
  }
  depends_on = [yandex_lb_target_group.nlb-group-grafana]
}
```
Проверим
```
kubectl get svc -w
NAME                                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
alertmanager-operated                       ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP   6h53m
diploma-svc                                 NodePort    10.233.5.22     <none>        80:30903/TCP                 146m
grafana                                     NodePort    10.233.7.61     <none>        3000:30902/TCP               6h50m
kubernetes                                  ClusterIP   10.233.0.1      <none>        443/TCP                      7h48m
prometheus-operated                         ClusterIP   None            <none>        9090/TCP                     6h53m
prometheus-stack-grafana                    ClusterIP   10.233.63.161   <none>        80/TCP                       6h53m
prometheus-stack-kube-prom-alertmanager     ClusterIP   10.233.34.154   <none>        9093/TCP,8080/TCP            6h53m
prometheus-stack-kube-prom-operator         ClusterIP   10.233.2.29     <none>        443/TCP                      6h53m
prometheus-stack-kube-prom-prometheus       ClusterIP   10.233.51.106   <none>        9090/TCP,8080/TCP            6h53m
prometheus-stack-kube-state-metrics         ClusterIP   10.233.42.87    <none>        8080/TCP                     6h53m
prometheus-stack-prometheus-node-exporter   ClusterIP   10.233.47.126   <none>        9100/TCP                     6h53m
```
Проверим в браузере
![]() grafama image

[app - наш load balancer](http://51.250.34.133/) 

[grafana](http://51.250.40.131:3000)  

![app image]()  

![yandex cloud resources]()

</details>

  
<details><summary>Установка и настройка CI/CD</summary>

Для CI/CD воспользуемся GitHub Actions

[repository link]()

[CICD манифест]()

В настройках репозитория нашего приложения зададим необходимые secrets и variables

![secrets image]()

Наш манифест (расположен в /.github/workflows) - link cicd.yml

```
name: CICD

env:
  IMAGE_NAME: ${{ secrets.DOCKER_USERNAME }}/diploma
  TAG: ${{ github.run_number }}
  FILE_TAG: ./environments/value_tag
  VARS_APP_REPO: ${{ vars.APP_REPO }}
  REPO_DIR: app
  
on:
  push:
    branches:
    - main
    tags:
    - '*'
   
jobs:

  build:
    outputs:
      image_tag: ${{ env.TAG }}
    runs-on: ubuntu-latest

    steps:
    
    - name: Get files
      uses: actions/checkout@v3

    - name: Set env TAG
      id: step_tag
      run: echo "TAG=$(echo ${GITHUB_REF:10})" >> $GITHUB_ENV
      if: startsWith(github.ref, 'refs/tags/v')
      
    - name: Build the Docker image
      run: docker build . --file Dockerfile --tag ${{ env.IMAGE_NAME }}:${{ env.TAG }}
    
    - name: Push the Docker image
      run: |
        docker login --username ${{ secrets.DOCKER_USERNAME }} --password ${{ secrets.DOCKER_PASSWORD }}
        docker push ${{ env.IMAGE_NAME }}:${{ env.TAG }}


  deploy: 
    
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest

    steps:

    - name: Update application
      env:
        tag: ${{ needs.build.outputs.image_tag }}
      uses: appleboy/ssh-action@v1.0.3
      with:
        host: ${{ secrets.SSH_HOST }}
        username: ${{ secrets.SSH_USERNAME }}
        key: ${{ secrets.SSH_KEY }}
        port: ${{ secrets.SSH_PORT }}
        script: |
          sudo su 
          sudo apt install git -y
          kubectl delete -f /app/kuber/deployment.yaml
          kubectl delete -f /app/kuber/service.yaml
          rm -rf /${{ env.REPO_DIR}}
          git clone ${{ env.VARS_APP_REPO }} /${{ env.REPO_DIR}}
          cd /${{ env.REPO_DIR}}
          sed -i "s|{{image_tag}}|${{ env.tag }}|g" kuber/deployment.yaml
          sudo kubectl apply -f kuber/deployment.yaml
          sudo kubectl apply -f kuber/service.yaml
          sudo kubectl get po,svc | grep diploma
```
Во время сборки docker image, build осуществляется на основе ранее созданного [Dockerfile](), а deploy организован с помощью ранее упомянутых [deployment.yml]() и [service.yml]() - в нашем k8s создаются объекты, на основе данных манифестов

Сделаем небольшое изменение в нашем приложении и проверим
```

```

</details>
  
## Что необходимо для сдачи задания?

1. Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
2. Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
3. Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
4. Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
5. Репозиторий с конфигурацией Kubernetes кластера.
6. Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
7. Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)
