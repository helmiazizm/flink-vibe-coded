node_id=$(docker exec garage /garage node id | cut -d'@' -f1)
echo "Node ID: $node_id"
docker exec garage /garage layout assign -z dc1 -c 1G "$node_id"
docker exec garage /garage layout apply --version 1
docker exec garage /garage bucket create paimon-data
docker exec garage /garage key create paimon-real-key
docker exec garage /garage bucket allow --read --write paimon-data --key paimon-real-key
docker exec garage /garage key info paimon-real-key --show-secret
