.PHONY: replace-vms

replace-vms:
	@echo "Re-creating selected instances..."
	terraform -chdir=./infra apply \
		-replace="google_compute_instance.controller[0]" \
		-replace="google_compute_instance.jumpbox" \
		-replace="google_compute_instance.worker[0]" \
		-replace="google_compute_instance.worker[1]" \
		-auto-approve
