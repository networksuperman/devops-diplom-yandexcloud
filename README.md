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



</details>
  
<details><summary>Подготовка cистемы мониторинга и деплой приложения</summary>



</details>
  
<details><summary>Установка и настройка CI/CD</summary>



</details>
  
## Что необходимо для сдачи задания?

1. Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
2. Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
3. Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
4. Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
5. Репозиторий с конфигурацией Kubernetes кластера.
6. Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
7. Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)
