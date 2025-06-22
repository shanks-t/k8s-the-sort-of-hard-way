# Imperative vs. Declarative Configuration Management

## 1. Welcome & Learning Objectives

* **Understand** the core difference between *imperative* and *declarative* paradigms.
* **Recognize** real‑world tools that embody each style (Terraform, Kubernetes, SQL, gcloud, bash).
* **Evaluate** strengths, weaknesses, and appropriate use‑cases for both paradigms.

---

## 2. Framing the Problem

Modern DevOps demands **repeatability, speed, safety, and compliance**.

* *Imperative* is like following a recipe step‑by‑step.
* *Declarative* is like telling a chef the dish you want–the kitchen handles the details.

---

## 3. Imperative Paradigm

* **Definition:** *Tell the system **how** to achieve a goal.*
* **Typical tools:** shell scripts, direct CLI calls (`gcloud`, `kubectl run`, `aws`), ad‑hoc Ansible.
* **Strengths:** quick prototyping, fine‑grained procedural control.
* **Weaknesses:** configuration drift, partial‑failure risk, weak audit trail.

---

## 4. Declarative Paradigm

* **Definition:** *Describe **what** the end‑state should be; the engine figures out **how**.*
* **Key properties:** idempotency, reconciliation loops, diff‑based planning.
* **Ecosystem examples:**

  * **Terraform** – cloud infrastructure.
  * **Kubernetes YAML** – container orchestration.
  * **SQL** – declarative data querying & schema.

---

## 5. SQL – The Original Declarative Language

```sql
-- Query: average temperature per city
SELECT city, AVG(temp)
FROM   weather
GROUP  BY city;
```

> You never specify index scans or join order; the **optimizer** works that out—mirroring how Terraform or Kubernetes controllers reconcile desired state.

Schema declarations are also declarative:

```sql
CREATE TABLE weather (
  id          SERIAL PRIMARY KEY,
  city        TEXT,
  temp        NUMERIC,
  recorded_at TIMESTAMP
);
```

---

## 6. Case Study 1 – Terraform vs. gcloud (Compute Engine VM)

### 6.1 Declarative (Terraform)

```hcl
# main.tf
provider "google" {
  project = "my-gcp-project"
  region  = "us-central1"
}

resource "google_compute_instance" "app_server" {
  name         = "app-server-01"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "trey:${file("~/.ssh/id_rsa.pub")}"
  }
}
```

```bash
terraform init   # download provider plug‑ins
terraform plan   # diff current vs desired state
terraform apply  # converge infra to config
```

### 6.2 Imperative (gcloud CLI)

```bash
# Create the VM imperatively
gcloud compute instances create app-server-01 \
    --project=my-gcp-project \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=ssh-keys="trey:$(cat ~/.ssh/id_rsa.pub)"

# Later, scale up manually
gcloud compute instances set-machine-type app-server-01 \
    --zone=us-central1-a \
    --machine-type=e2-highcpu-4
```

> **Observation:** You must remember every mutation command.  Terraform instead *calculates* the diff.

---

## 7. Case Study 2 – Kubernetes in Depth

### 7.1 Declarative Manifests

`deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  revisionHistoryLimit: 2       # keep last two ReplicaSets
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: gcr.io/my-gcp-project/web-app:1.0.0
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
```

`service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

**Apply desired state**

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

#### Reconciliation Workflow

1. **API Server** stores manifests in etcd (desired state).
2. **Deployment controller** creates a ReplicaSet with `replicas=3`.
3. **ReplicaSet controller** spawns three Pods.
4. **Kubelet** on each node starts containers via containerd.
5. If a Pod is deleted, ReplicaSet immediately recreates it to restore desired state.

### 7.2 Imperative Alternative

```bash
# Create deployment imperatively (no YAML saved)
kubectl run web-app \
  --image=gcr.io/my-gcp-project/web-app:1.0.0 \
  --replicas=3 \
  --port=80

# Expose service imperatively
kubectl expose deployment web-app --type=LoadBalancer --port=80

# Update image later
kubectl set image deployment/web-app \
  web=gcr.io/my-gcp-project/web-app:1.1.0
```

> **Limitation:** Commands aren’t version‑controlled; desired intent lives only in CLI history.

---

## 8. Detailed Comparison Table

| Attribute        | Imperative         | Declarative                              |
| ---------------- | ------------------ | ---------------------------------------- |
| Change Unit      | Command / script   | Config file (desired state)              |
| Failure Handling | Manual retry logic | Automatic reconciliation                 |
| Drift Detection  | External tooling   | Built‑in (controllers/plan)              |
| Auditability     | Shell history      | Git diff of manifests / `.tf` files      |
| Learning Curve   | Low upfront        | Higher upfront, lower ongoing complexity |

---

## 9. When Imperative Still Wins

* Exploratory debugging (`kubectl exec`, `gcloud ssh`).
* Complex branching workflows (e.g., data migrations).
* Emergency, time‑critical “break glass” operations (with strict controls).

---

## 10. Migration & Pitfalls

* **Anti‑patterns:** Manual `kubectl edit` on live objects; `terraform state rm` without config change.
* **State management:** Locking & remote back‑ends (Terraform).
* **Manifest sprawl:** Use Kustomize, Helm, or GitOps repositories.

---

## 11. Summary & Key Takeaways

1. **Declarative manifests/specs** capture *intent*, survive team turnover, and drive GitOps.
2. **Controllers & planners** translate specs into reality and continuously heal drift.
3. **SQL’s longevity** proves declarative languages scale across decades and domains.
4. Reserve **imperative** commands for ad‑hoc or break‑glass scenarios; rely on **declarative** workflows for day‑to‑day infrastructure.

---

## 12. Q & A

---

### Further Reading

* *Kubernetes: Up & Running*, 3rd ed. – Burns, Beda, & Hightower.
* *Terraform: Up & Running*, 3rd ed. – Yevgeniy Brikman.
* Google Cloud Article: “Declarative vs. Imperative Infrastructure”.
* ACM Paper: “SEQUEL and SQL – Early History of Declarative Data Access”.
