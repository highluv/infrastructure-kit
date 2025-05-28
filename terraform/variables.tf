variable access_key {
    default = ""
    type = string
}

variable secret_key {
    default = ""
    type = string
}

variable public_key {
    default = ""
    type = string
}

variable az {
    default = "ru-msk-vol51"
    type = string
}


variable "instance_type"{
  default = ""
  type = string
}

variable "data_hdd_size" {
  default = 104
  type = number
}

variable "ami_id" {
  default = ""
  type = string
}

variable "host_config" {
  type = map(object({
    ip          = string
    data_disk   = string
    data_size   = number
  }))
}
