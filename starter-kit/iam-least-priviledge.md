# IAM Least Privilege Design

## Overview

This design applies the principle of least privilege, which means granting only the minimum permissions required for a task.


### Use Case

The KijaniKiosk application needs to read product images and files stored in cloud storage.


## IAM Role

An IAM role is created for the application with permission to read objects only from a specific storage bucket.



### Policy Definition

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::kijaniosk-assets/*"
    }
  ]
}



### Explanation

- **Action: s3:GetObject**
  - Allows only reading files from storage
  - Prevents uploading, deleting, or modifying files

- **Resource**
  - Restricted to a specific bucket (`kijaniosk-assets`)
  - Prevents access to other storage resources

- **Effect: Allow**
  - Grants permission only for the defined action



#### Why This Follows Least Privilege

- No write or delete permissions are granted
- Access is limited to only required resources
- Reduces risk of accidental or malicious changes



## Benefits

- Improves security by limiting access
- Protects sensitive data
- Minimizes impact in case of compromise



## Conclusion

This IAM policy ensures that the application can perform its required task (reading files) while maintaining strict access control, aligning with DevOps security best practices.