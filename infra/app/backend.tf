terraform {
  # Để rỗng có chủ đích: giá trị truyền lúc init qua -backend-config=backend.hcl.
  # Nhờ vậy cùng một code dùng được cho nhiều môi trường/subscription mà không sửa file.
  backend "azurerm" {}
}
