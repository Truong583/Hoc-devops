#!/usr/bin/env bash

set -e

# Đặt region là Singapore
export AWS_DEFAULT_REGION="ap-southeast-1"
user_data=$(cat user-data.sh)

echo "Đang tạo Security Group..."
security_group_id=$(aws ec2 create-security-group \
  --group-name "sample-app-$(date +%s)" \
  --description "Allow HTTP traffic into the sample app" \
  --output text \
  --query GroupId)

aws ec2 authorize-security-group-ingress \
  --group-id "$security_group_id" \
  --protocol tcp \
  --port 80 \
  --cidr "0.0.0.0/0" > /dev/null

echo "Đang tìm kiếm Amazon Linux 2023 AMI mới nhất..."
image_id=$(aws ec2 describe-images \
  --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-x86_64' \
  --query 'reverse(sort_by(Images, &CreationDate))[:1] | [0].ImageId' \
  --output text)

echo "Đang khởi tạo EC2 Instance..."
# LƯU Ý QUAN TRỌNG: KHÔNG ĐỔI THÀNH t2.micro! Tài khoản của bạn CHỈ cho phép dùng t3.micro làm Free Tier.
instance_id=$(aws ec2 run-instances \
  --image-id "$image_id" \
  --instance-type "t3.micro" \
  --security-group-ids "$security_group_id" \
  --user-data "$user_data" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-app}]' \
  --output text \
  --query Instances[0].InstanceId)

echo "Đang chờ instance khởi động để lấy Public IP..."
# BỔ SUNG: Chờ đến khi trạng thái instance là 'running' để chắc chắn IP đã được gán
aws ec2 wait instance-running --instance-ids "$instance_id"

public_ip=$(aws ec2 describe-instances \
  --instance-ids "$instance_id" \
  --output text \
  --query 'Reservations[*].Instances[*].PublicIpAddress')

echo "----------------------------------------"
echo "✅ HOÀN TẤT!"
echo "Instance ID = $instance_id"
echo "Security Group ID = $security_group_id"
echo "Public IP = $public_ip"
echo "----------------------------------------"
