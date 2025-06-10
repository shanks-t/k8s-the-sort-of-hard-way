````markdown
# OS Login SSH Configuration Plan for KTHW Infrastructure

This document outlines the step-by-step plan to migrate your current Terraform setup to **use OS Login** for SSH across your Jumpbox, Controller, and Worker VMs. You can hand this to your Claude Code agent for implementation.

---

## 1. Enable OS Login on Your Project

**Why?**
OS Login delegates SSH key management to IAM instead of instance metadata, enabling centralized revocation, audit, and multi-user support.

**Terraform Action**
```hcl
resource "google_project_metadata_item" "enable_oslogin" {
  project = var.project_id
  key     = "enable-oslogin"
  value   = "TRUE"
}
````

> *Alternatively*, enable OS Login per-VM via metadata (see Step 5).

---

## 2. Grant the Required IAM Roles

**Why?**
Without the correct IAM roles, OS Login won’t permit SSH access (or sudo/root escalation).

**Terraform Action**

```hcl
resource "google_project_iam_member" "oslogin_user" {
  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = "user:${var.ssh_user_email}"
}

resource "google_project_iam_member" "oslogin_admin" {
  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "user:${var.ssh_user_email}"
}
```

> Replace `${var.ssh_user_email}` with your Google identity (e.g. `treyshanks@gmail.com`).

---

## 3. Remove Legacy `ssh-keys` Metadata

**Why?**
Once OS Login is enabled, metadata-injected SSH keys conflict with or are ignored by OS Login. Remove them to avoid confusion.

**Terraform Action**

* In each `google_compute_instance`, delete any line setting `ssh-keys` in `metadata`.

> **Before**:
>
> ```hcl
> metadata = {
>   ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
>   enable-oslogin = "TRUE"
> }
> ```
>
> **After**:
>
> ```hcl
> metadata = {
>   enable-oslogin = "TRUE"
> }
> ```

---

## 4. Confirm Network & Firewall Rules Remain Correct

**Why?**
OS Login does not affect network configuration. You still need your existing firewall rules to allow SSH (TCP/22) and internal communication.

**Check:**

* `google_compute_firewall.allow_ssh` targets the correct VPC and tags (`ssh`).
* Jumpbox VM retains `tags = ["ssh", "jumpbox"]`.

---

## 5. Add `enable-oslogin` to Each VM Definition

**Why?**
Tagging each instance ensures OS Login is active (in case you opted for per-VM enablement instead of project-wide).

**Terraform Action**
For **jumpbox**, **controller**, and **worker** resources:

```hcl
resource "google_compute_instance" "<role>" {
  # … your existing settings …

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = <<-EOF
    ${local.common_setup_script}
    ${local.<role>_setup_script}
  EOF
}
```

> Replace `<role>` with `jumpbox`, `controller`, or `worker` and merge in your existing startup scripts.

---

## 6. (Optional) Manage SSH Keys via `google_os_login_ssh_public_key`

**Why?**
Instead of manually uploading keys via UI, you can push your public key into IAM so OS Login picks it up automatically.

**Terraform Action**

```hcl
resource "google_os_login_ssh_public_key" "my_key" {
  parent               = "users/${var.ssh_user_email}"
  key                  = file("${path.module}/keys/id_rsa.pub")
  expiration_time_usec = (timestamp() + 31536000000000)  # ~1 year
}
```

---

## 7. Test the SSH Flow

1. **Apply Terraform:**

   ```bash
   terraform apply
   ```
2. **SSH to the Jumpbox:**

   ```bash
   ssh -i ~/.ssh/id_rsa ${var.ssh_user}@<jumpbox-ip>
   ```
3. **SSH to Internal Nodes (no key copy needed):**

   ```bash
   ssh ${var.ssh_user}@10.240.0.10    # controller
   ssh ${var.ssh_user}@10.240.0.20    # worker-0
   ```

If authentication succeeds without manual key copying, OS Login is correctly configured.

---

## 8. Document & Automate

* **Commit** these Terraform changes to version control.
* **Update** your team’s runbook to reference OS Login (remove old `ssh-keys` steps).
* **Integrate** `terraform plan && terraform apply` into your CI/CD pipeline.

---

### Summary Checklist

* [ ] Enable OS Login at project or VM level
* [ ] Grant `roles/compute.osLogin` and `roles/compute.osAdminLogin`
* [ ] Remove all `ssh-keys` metadata
* [ ] Confirm firewall rules and tags
* [ ] Add `enable-oslogin = "TRUE"` to VMs
* [ ] (Optional) Create `google_os_login_ssh_public_key`
* [ ] Test SSH flow: local → jumpbox → controller/worker
* [ ] Update runbooks/automation

```
```
