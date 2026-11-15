variable "tags" {
    type = {}
    default = {
        Environment="dev"
        Owner="Terraform"
    }
  
}
variable "os" {
    type = "string"
    default = "linux"
  
}