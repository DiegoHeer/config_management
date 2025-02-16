terraform {
  required_version = ">=1.10.5"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">=3.0.2"
    }
  }
}