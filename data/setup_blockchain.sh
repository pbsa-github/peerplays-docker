#!/bin/bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install expect jq curl -y
CHAIN_ID=$(curl --silent --data '{"jsonrpc": "2.0", "method": "get_chain_properties", "params": [], "id": 1}' http://127.0.0.1:8090/rpc | jq -r ".result.chain_id")
PASSWORD=$1
#!/usr/bin/expect -f
#set CHAIN_ID [lindex $argv 0];
{
    /usr/bin/expect << EOF
    spawn cli_wallet --chain-id $CHAIN_ID --server-rpc-endpoint ws://127.0.0.1:8090
    expect -exact "new >>> "
    send -- "set_password $PASSWORD\r"
    expect -exact "locked >>> "
    send -- "unlock $PASSWORD\r"
    expect -exact "unlocked >>> "
    send -- "import_key nathan \"5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3\"\r"
    expect -exact "unlocked >>> "
    send -- "import_balance nathan \[\"5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3\"\] true\r"
    expect -exact "unlocked >>> "
    send -- "upgrade_account nathan true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init0 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init1 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init2 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init3 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init4 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init5 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init6 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init7 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init8 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init9 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
    send -- "transfer nathan init10 100000 TEST \"here is the cash\" true\r"
    expect -exact "unlocked >>> "
EOF
}
