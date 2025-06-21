provider "aws" {
  region = "eu-north-1" # Or your desired AWS region
}

resource "aws_s3_bucket" "static_website_bucket" {
  bucket = "my-Amazon-static-website" # Replace with a unique bucket name
  # acl = "public-read" # Keep this commented out or removed as per previous fix

  website {
    index_document = "index.html"
  }

  tags = {
    Project     = "StaticWebsiteDeployment"
    Environment = "Production"
  }
}

# --- Add this Block Public Access resource ---
resource "aws_s3_bucket_public_access_block" "static_website_bucket_public_access_block" {
  bucket = aws_s3_bucket.static_website_bucket.id

  # Set these to false to allow public policies for static website hosting
  block_public_acls       = false # Not strictly needed for bucket policies, but good to set if you ever considered ACLs
  block_public_policy     = false
  ignore_public_acls      = false # Not strictly needed for bucket policies
  restrict_public_buckets = false
}
# --- End of Block Public Access resource ---


resource "aws_s3_bucket_policy" "static_website_bucket_policy" {
  bucket = aws_s3_bucket.static_website_bucket.id

  # Ensure this policy allows GetObject for public read
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "PublicReadGetObject",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": [
          "${aws_s3_bucket.static_website_bucket.arn}/*"
        ]
      }
    ]
  })

  # Add a dependency to ensure the public access block is configured first
  depends_on = [aws_s3_bucket_public_access_block.static_website_bucket_public_access_block]
}

output "website_endpoint" {
  value = aws_s3_bucket.static_website_bucket.website_endpoint
}
    
    
   


     

 
 
