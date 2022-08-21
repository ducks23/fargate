resource "aws_ecr_repository" "django_repo" {
  name                 = "django_api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
