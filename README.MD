
# Documentação do Processo de Deploy no OpenShift

## Sumário

1. [Login no OpenShift](#1-login-no-openshift)
2. [Criação de um Novo Projeto](#2-criação-de-um-novo-projeto)
3. [Configuração do Persistent Volume (PV)](#3-configuração-do-persistent-volume-pv)
4. [Configuração do Persistent Volume Claim (PVC)](#4-configuração-do-persistent-volume-claim-pvc)
5. [Login no Registro Interno do OpenShift](#5-login-no-registro-interno-do-openshift)
6. [Construção e Publicação da Imagem Docker](#6-construção-e-publicação-da-imagem-docker)
7. [Criação do Deployment](#7-criação-do-deployment)
8. [Criação do Serviço](#8-criação-do-serviço)
9. [Criação da Rota](#9-criação-da-rota)
10. [Configuração do Horizontal Pod Autoscaler (HPA)](#10-configuração-do-horizontal-pod-autoscaler-hpa)
11. [Verificação do Status dos Recursos](#11-verificação-do-status-dos-recursos)
12. [Acesso à Aplicação](#12-acesso-à-aplicação)
13. [Teardown do Ambiente](#13-teardown-do-ambiente)

## 1. Login no OpenShift

Execute o comando abaixo para fazer login no OpenShift:

```bash
oc login -u kubeadmin -p Y9hGk-K7fvJ-p359Z-ACeL3 --server=https://api.crc.testing:6443
```

### Exemplo de Saída do Comando:

```plaintext
Login successful.
```

## 2. Criação de um Novo Projeto

Crie um novo projeto chamado `fiap-app`:

```bash
oc new-project fiap-app
```

### Exemplo de Saída do Comando:

```plaintext
Now using project "fiap-app" on server "https://api.crc.testing:6443".
```

## 3. Configuração do Persistent Volume (PV)

Crie um arquivo chamado `pv.yaml` com o seguinte conteúdo:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: fiap-app-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  hostPath:
    path: /app/data
```

Aplique o PV:

```bash
oc apply -f pv.yaml
```

### Exemplo de Saída do Comando:

```plaintext
persistentvolume/fiap-app-pv created
```

## 4. Configuração do Persistent Volume Claim (PVC)

Crie um arquivo chamado `pvc.yaml` com o seguinte conteúdo:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fiap-app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Aplique o PVC:

```bash
oc apply -f pvc.yaml
```

### Exemplo de Saída do Comando:

```plaintext
persistentvolumeclaim/fiap-app-pvc created
```

## 5. Login no Registro Interno do OpenShift

Execute os comandos abaixo para fazer login no registro interno do OpenShift e autenticar o Docker:

```bash
docker login -u kubeadmin -p $(oc whoami -t) default-route-openshift-image-registry.apps-crc.testing
```

### Exemplo de Saída do Comando:

```plaintext
Login Succeeded
```

## 6. Construção e Publicação da Imagem Docker

Construa a imagem Docker localmente:

```bash
docker build -t fiap-app:latest .
```

### Exemplo de Saída do Comando:

```plaintext
Successfully built <image_id>
Successfully tagged fiap-app:latest
```

Marque a imagem para o registro interno do OpenShift:

```bash
docker tag fiap-app:latest default-route-openshift-image-registry.apps-crc.testing/fiap-app/fiap-app:latest
```

Empurre a imagem para o registro interno:

```bash
docker push default-route-openshift-image-registry.apps-crc.testing/fiap-app/fiap-app:latest
```

### Exemplo de Saída do Comando:

```plaintext
The push refers to repository [default-route-openshift-image-registry.apps-crc.testing/fiap-app/fiap-app]
latest: digest: sha256:a65b6c711c7dba258519990c962101b80d20bd4763f13af4c693aa4d41889a04 size: 2202
```

## 7. Criação do Deployment

Crie um arquivo chamado `deployment.yaml` com o seguinte conteúdo:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fiap-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fiap-app
  template:
    metadata:
      labels:
        app: fiap-app
    spec:
      containers:
      - name: fiap-app
        image: default-route-openshift-image-registry.apps-crc.testing/fiap-app/fiap-app:latest
        ports:
        - containerPort: 5000
        volumeMounts:
        - mountPath: /app/data
          name: fiap-data
      volumes:
      - name: fiap-data
        persistentVolumeClaim:
          claimName: fiap-app-pvc
```

Aplique o Deployment:

```bash
oc apply -f deployment.yaml
```

### Exemplo de Saída do Comando:

```plaintext
deployment.apps/fiap-app created
```

## 8. Criação do Serviço

Crie um arquivo chamado `service.yaml` com o seguinte conteúdo:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: fiap-app
spec:
  selector:
    app: fiap-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
```

Aplique o Serviço:

```bash
oc apply -f service.yaml
```

### Exemplo de Saída do Comando:

```plaintext
service/fiap-app created
```

## 9. Criação da Rota

Crie um arquivo chamado `route.yaml` com o seguinte conteúdo:

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: fiap-app
spec:
  to:
    kind: Service
    name: fiap-app
  port:
    targetPort: 5000
```

Aplique a Rota:

```bash
oc apply -f route.yaml
```

### Exemplo de Saída do Comando:

```plaintext
route.route.openshift.io/fiap-app created
```

## 10. Configuração do Horizontal Pod Autoscaler (HPA)

Crie um arquivo chamado `hpa.yaml` com o seguinte conteúdo:

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: fiap-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fiap-app
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

Aplique o HPA:

```bash
oc apply -f hpa.yaml
```

### Exemplo de Saída do Comando:

```plaintext
horizontalpodautoscaler.autoscaling/fiap-app-hpa created
```

## 11. Verificação do Status dos Recursos

Verifique o status dos pods:

```bash
oc get pods -n fiap-app
```

### Exemplo de Saída do Comando:

```plaintext
NAME                          READY   STATUS    RESTARTS   AGE
fiap-app-5797d5777-khmrf      1/1     Running   0          5m
```

Verifique o status do serviço e da rota:

```bash
oc get svc -n fiap-app
```

### Exemplo de Saída do Comando:

```plaintext
NAME       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
fiap-app   ClusterIP   172.30.227.186   <none>        80/TCP     5m
```

```bash
oc get routes -n fiap-app
```

### Exemplo de Saída do Comando:

```plaintext
NAME       HOST/PORT                                            PATH   SERVICES   PORT       TERMINATION   WILDCARD
fiap-app   fiap-app-fiap-app.apps-crc.testing                           fiap-app   5000                    None
```

## 12. Acesso à Aplicação

Acesse a aplicação via navegador utilizando a URL fornecida pela rota. No caso do exemplo acima, a URL seria:

```
http://fiap-app-fiap-app.apps-crc.testing
```

## 13. Teardown do Ambiente

Para destruir o ambiente criado, execute os seguintes comandos:

```bash
oc delete project fiap-app
oc delete pv fiap-app-pv
```

### Exemplo de Saída do Comando:

```plaintext
project "fiap-app" deleted
persistentvolume "fiap-app-pv" deleted

```

## 13. Referências

- [OpenShift CLI Reference](https://docs.openshift.com/container-platform/4.6/cli_reference/openshift_cli/getting-started-cli.html)

- [OpenShift API Reference](https://docs.openshift.com/container-platform/4.6/rest_api/index.html)

- [OpenShift Documentation](https://docs.openshift.com/container-platform/4.6/welcome/index.html)

- [Docker CLI Reference](https://docs.docker.com/engine/reference/commandline/cli/)

- [Docker Documentation](https://docs.docker.com/)

- [Kubernetes API Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/)

- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

- [YAML Reference](https://yaml.org/spec/1.2/spec.html)

- [Markdown Reference](https://www.markdownguide.org/basic-syntax/)

## 14. Anexos

- [Deployment.yaml](./openshift-config.yaml)

- [Exemplo de Arquivo de Configuração do Docker](./Dockerfile)

- [Exemplo de Arquivo de Configuração do Kubernetes](./kubernetes-config.yaml)

- [Exemplo de Arquivo de Configuração do YAML](./yaml-config.yaml)

