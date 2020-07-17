#!/bin/bash
# for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
        BTC_CONF_PATH="$(greadlink -f ../bitcoin/regtest/bitcoin.conf)"
else
	BTC_CONF_PATH="$(readlink -f ../bitcoin/regtest/bitcoin.conf)"
fi
sed -i '' "s|BTC_REGTEST_CONF=.*|BTC_REGTEST_CONF=\"$BTC_CONF_PATH\"|g" ../.env
