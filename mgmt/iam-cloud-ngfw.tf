resource "aws_iam_role" "ngfw_role" {
  name = "pan-CloudNGFWRole"

  inline_policy {
    name = "apigateway_policy"

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "execute-api:Invoke",
            "execute-api:ManageConnections"
          ],
          "Resource" : "arn:aws:execute-api:*:*:*"
        }
      ]
    })
  }

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "apigateway.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:sts::788337323161:assumed-role/AWSReservedSSO_AWSAdministratorAccess_e8497e9645670c39/rweglarz@paloaltonetworks.com"
          ]
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    CloudNgfwRulestackAdmin       = "Yes"
    CloudNGFWFirewallAdmin        = "Yes"
    //CloudNGFWGlobalRulestackAdmin = "Yes"
  }
}

output "cloud-ngfw-role" {
  value = aws_iam_role.ngfw_role.arn
}
