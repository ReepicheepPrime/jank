#!/bin/bash
echo ECS_CLUSTER=${cluster} >> /etc/ecs/ecs.config
echo ECS_AVAILABLE_LOGGING_DRIVERS='["json-file","awslogs"]' >> /etc/ecs/ecs.config

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
# sudo yum install -y iptables-services; sudo iptables --insert FORWARD 1 --in-interface docker+ --destination 169.254.169.254/32 --jump DROP
# sudo iptables-save | sudo tee /etc/sysconfig/iptables && sudo systemctl enable --now iptables
# echo ECS_AWSVPC_BLOCK_IMDS=true >> /etc/ecs/ecs.config
echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config