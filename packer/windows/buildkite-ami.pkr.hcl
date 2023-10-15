packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "arch" {
  type    = string
  default = "x86_64"
}

variable "instance_type" {
  type    = string
  default = "m7a.xlarge"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "build_number" {
  type    = string
  default = "none"
}

variable "released" {
  type    = boolean
  default = false
}

data "amazon-ami" "windows-server-2019" {
  filters = {
    name                = "Windows_Server-2019-English-Full-*"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.region
}

source "amazon-ebs" "elastic-ci-stack" {
  ami_description = "Buildkite Elastic Stack (Windows Server 2019 w/ docker)"
  ami_groups      = ["all"]
  ami_name        = "buildkite-stack-windows-{{ clean_resource_name `${timestamp()}` }}"
  communicator    = "winrm"
  instance_type   = var.instance_type
  region          = var.region
  source_ami      = data.amazon-ami.windows-server-2019.id
  user_data_file  = "scripts/ec2-userdata.ps1"
  winrm_insecure  = true
  winrm_use_ssl   = true
  winrm_username  = "Administrator"

  tags = {
    OSVersion   = "Amazon Linux 2023"
    BuildNumber = var.build_number
    Released    = var.released
  }
}

build {
  sources = ["source.amazon-ebs.elastic-ci-stack"]

  provisioner "file" {
    destination = "C:/packer-temp"
    source      = "conf"
  }

  provisioner "file" {
    destination = "C:/packer-temp"
    source      = "../../plugins"
  }

  provisioner "powershell" {
    script = "scripts/install-utils.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-cloudwatch-agent.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-lifecycled.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-docker.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-buildkite-agent.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-s3secrets-helper.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-session-manager-plugin.ps1"
  }

  provisioner "powershell" {
    inline = ["Remove-Item -Path C:/packer-temp -Recurse"]
  }

  provisioner "powershell" {
    inline = ["C:/ProgramData/Amazon/EC2-Windows/Launch/Scripts/InitializeInstance.ps1 -Schedule", "C:/ProgramData/Amazon/EC2-Windows/Launch/Scripts/SysprepInstance.ps1 -NoShutdown"]
  }
}
