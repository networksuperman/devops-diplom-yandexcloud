resource "yandex_iam_service_account" "sa" {
  folder_id = var.folder_id
  name = "bucket-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_kms_symmetric_key" "key-a" {
  name              = "myencrypts"
  description       = "key adding encryption to a bucket"
  default_algorithm = "AES_128"
  rotation_period   = "8760h"
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "panarin-state-bucket"
}

data "yandex_iam_policy" "editor" {
  binding {
    role = "storage.editor"

    members = [
      "userAccount:${yandex_iam_service_account.sa.id}",
    ]
  }
}

resource "yandex_iam_service_account_iam_policy" "editor-account-iam" {
  service_account_id = "${yandex_iam_service_account.sa.id}"
  policy_data        = "${data.yandex_iam_policy.editor.policy_data}"
}

resource "local_file" "providers" { 
  content = templatefile("../terraform/template/providers.tftpl", {
    bucket_name = "panarin-state-bucket"
    access_key  = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    secret_key  = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    cloud_id    = var.cloud_id
    folder_id   = var.folder_id
  })
  filename = "../terraform/providers.tf"
}
