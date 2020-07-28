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

    expect "unlocked >>> "
    send "create_account_with_brain_key \"CHOROGI EERIE RETUCK PRAECOX MUDDLER LITERAL ACRON CARBRO BABBY AGAZED UNBOLT ABASED HALA TEMBLOR EMANATE HEMIPIC\" sonaccount01 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"PATIENT PINDY NEARISH FATBIRD OVERCUP DEVOICE ORCHAT DURMAST HAFFET QUADRAT STUPA TUBIFER NIGGLER GUABA CHUMP BLUECAP\" sonaccount02 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"PINCHER KEELMAN PARI ULEXITE EXPECT PLOVER KAMIAS VINEAL KAWIKA STIPES KILDEE COLEUR NESTLE FAIPULE COTUTOR ACIER\" sonaccount03 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"FORFARS GYMEL THEASUM TOCHER BEWITCH GASHLY FALLING FARCING EYELINE RELBUN GIARRA SUBPLOW SPRITE FORPINE RUSSETY REGLOW\" sonaccount04 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"CYCLENE LUSK SHOPHAR SLABMAN GRAINY OUTSHOW TAXMAN DEICTIC PIQUE WEJACK ADEEP DINGHEE CREEDAL APAGOGE WINT FLEW\" sonaccount05 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"SMALLS UNVIVID AZOTIZE UNBASED HIGHTOP EDDY MOLTEN URARE COLUMN MUSCOID PUFFILY VENTAGE INDULT DEEPLY FU TOWNISH\" sonaccount06 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"DEPHASE LYXOSE KUVASZ GROOVER CARACOL FACIEND VEND BAINIE PALGAT HERO MUCONIC FULGENT LOBTAIL LOOSER NUMERO CERE\" sonaccount07 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"TIKLIN GOOK HAUNT UNITUDE ENDORAL ALOOF WAST AMPER FERULE OVERARM SIGMATE NYMPHLY ESTUARY VETOER WARDAY ROYAL\" sonaccount08 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"DEGUM BACLIN WROTE RANGED PREDOOM DESS HIDEOUS MUCIN UNGNAW ARRIVAL SKILLED ZINCO ONYMIZE BUNTON LAVANGA KRAUSEN\" sonaccount09 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"DULSE ANEPIA PRUNE PLIERS GABLE MACHILA MOWRA UNSNARE BABYDOM TIBET PACO BELAM RASP GLOTTIC SQUELCH OFFLET\" sonaccount10 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"TRIPARA DINGHEE NOOKLET GROANER TRINK CLOVERY CIVISM KEA GULAMAN UPGRADE ODDS TOFTMAN COATING PUCKREL NEIST VERVEL\" sonaccount11 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"SOCCER HAAB HATTOCK VEEP CLIMATE SIGIL VULTURN AVOW SAMAJ COVETER ALBUM ROTAN REREEVE ACROSE KOWTOW TERRINE\" sonaccount12 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"AIRAMPO BEAUTI DIANITE GROUP SKITE REIVER RADIAL YAFFLE FUNNY PHILTRA WERE UROLOGY PEAFOWL DIARIAN AUREOUS BELA\" sonaccount13 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"WOULDST RURBAN FLYFLAP UPFLASH BLEATY CHERUB KINGROW TACK TRUMPH VENT TEAMER PROTAX BEERAGE JARLDOM IMBAUBA UNPOWER\" sonaccount14 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"KAKKAK CACOON SOLOIST SWANGY RAISINY SHERIFA FOHAT FEIGHER BLOUT ISOTAC GROWER MOT MYELOID THRIPEL CHYLE FUROIC\" sonaccount15 nathan nathan true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "create_account_with_brain_key \"ALGATE BICHY FELTER JAGRATA THENAL STUNK BALDEN WATT KINKLY BOYLIKE HUNGER INNET WAR RETTERY LANEY UNGIVEN\" sonaccount16 nathan nathan true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount01 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount02 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount03 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount04 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount05 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount06 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount07 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount08 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount09 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount10 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount11 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount12 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount13 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount14 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount15 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan sonaccount16 50000000 TEST \"Wellcome payment\" true\r"

    expect "unlocked >>> "
    send "transfer nathan committee-account 50000000 TEST \"\" true\r"

    expect "unlocked >>> "
    send "transfer nathan witness-account 50000000 TEST \"\" true\r"

    expect "unlocked >>> "
    send "transfer nathan son-account 50000000 TEST \"\" true\r"

    expect "unlocked >>> "
    send "create_asset son-account PBTC 5 { \"max_supply\": \"1000000000000000\", \"market_fee_percent\": 0, \"max_market_fee\": \"1000000000000000\", \"issuer_permissions\": 79, \"flags\": 0, \"core_exchange_rate\": { \"base\": { \"amount\": 1, \"asset_id\": \"1.3.0\" }, \"quote\": { \"amount\": 1, \"asset_id\": \"1.3.1\" } }, \"whitelist_authorities\": \[\], \"blacklist_authorities\": \[\], \"whitelist_markets\": \[\], \"blacklist_markets\": \[\], \"description\": \"\", \"extensions\": \[\] } null true\r"

    sleep 2.0

    expect "unlocked >>> "
    send "upgrade_account sonaccount01 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount02 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount03 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount04 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount05 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount06 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount07 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount08 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount09 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount10 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount11 true\r"
    
    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount12 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount13 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount14 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount15 true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "upgrade_account sonaccount16 true\r"

    sleep 2.0

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount01 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount01 50 TEST son true\r"

    #expect "unlocked >>> "
    send "create_vesting_balance sonaccount02 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount02 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount02 50 TEST son true\r"

    #expect "unlocked >>> "
    send "create_vesting_balance sonaccount03 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount03 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount03 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount04 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount04 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount04 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount05 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount05 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount05 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount06 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount06 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount06 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount07 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount07 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount07 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount08 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount08 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount08 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount09 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount09 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount09 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount10 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount10 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount10 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount11 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount11 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount11 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount12 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount12 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount12 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount13 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount13 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount13 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount14 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount14 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount14 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount15 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount15 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount15 50 TEST son true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount16 50 TEST gpos true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount16 50 TEST normal true\r"

    expect "unlocked >>> "
    send "create_vesting_balance sonaccount16 50 TEST son true\r"

    sleep 1.0

    expect "unlocked >>> "
    send "try_create_son sonaccount01 \"http://sonaddreess01.com\" \[\[bitcoin, 03456772301e221026269d3095ab5cb623fc239835b583ae4632f99a15107ef275\], \[peerplays, TEST8TCQFzyYDp3DPgWZ24261fMPSCzXxVyoF3miWeTj6JTi2DZdrL\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount02 \"http://sonaddreess02.com\" \[\[bitcoin, 02d67c26cf20153fe7625ca1454222d3b3aeb53b122d8a0f7d32a3dd4b2c2016f4\], \[peerplays, TEST82qv1LKFvwVKD9pg5JQf6qqwLcoeqUniQjWJ3wKTodyWa7gHUs\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount03 \"http://sonaddreess03.com\" \[\[bitcoin, 025f7cfda933516fd590c5a34ad4a68e3143b6f4155a64b3aab2c55fb851150f61\], \[peerplays, TEST6xdp7MrEPnaNK9GuF3KTeTizgGN6JC5nPmxx81higFepSZ8N7r\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount04 \"http://sonaddreess04.com\" \[\[bitcoin, 0228155bb1ddcd11c7f14a2752565178023aa963f84ea6b6a052bddebad6fe9866\], \[peerplays, TEST55j32Up75gHCxJBPN18vEytL9anDgEVFtsaCii38keGQG71X22\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount05 \"http://sonaddreess05.com\" \[\[bitcoin, 037500441cfb4484da377073459511823b344f1ef0d46bac1efd4c7c466746f666\], \[peerplays, TEST68bX5bB16GkEAig6w2WTh9NbM9nHa66CemnDRx2njRY9bbWXhU\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount06 \"http://sonaddreess06.com\" \[\[bitcoin, 02ef0d79bfdb99ab0be674b1d5d06c24debd74bffdc28d466633d6668cc281cccf\], \[peerplays, TEST7mtTyM2rD18xDTtLTxWhq6W6zFgAgPFu9KHSFNsfWJXZNT8Wc8\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount07 \"http://sonaddreess07.com\" \[\[bitcoin, 0317941e4219548682fb8d8e172f0a8ce4d83ce21272435c85d598558c8e060b7f\], \[peerplays, TEST7RMDnipLkFaQ4vtDyVvgyCedRoxyT9JWpAoM9mrE7rwVSyezoB\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount08 \"http://sonaddreess08.com\" \[\[bitcoin, 0266065b27f7e3d3ad45b471b1cd4e02de73fc4737dc2679915a45e293c5adcf84\], \[peerplays, TEST51nSJ2q1C9htnYWfTv73JxEc4nBWPNxJtUGPGpD4XwxeLzAd8t\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount09 \"http://sonaddreess09.com\" \[\[bitcoin, 023821cc3da7be9e8cdceb8f146e9ddd78a9519875ecc5b42fe645af690544bccf\], \[peerplays, TEST8EmMMvQdAPzcnxymRUpbYdg8fArUY473QosCQpuPtWXxXtoNp4\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount10 \"http://sonaddreess10.com\" \[\[bitcoin, 0229ff2b2106b76c27c393e82d71c20eec32bcf1f0cf1a9aca8a237269a67ff3e5\], \[peerplays, TEST5815xbKy73Bx1LJWW1jg7GshWSEFWub3uoiEFP7FtP6z4YZtkU\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount11 \"http://sonaddreess11.com\" \[\[bitcoin, 024d113381cc09deb8a6da62e0470644d1a06de82be2725b5052668c8845a4a8da\], \[peerplays, TEST61qgG2v6JArygFiQCKypymxhBqg1wKmmbdkHeNkXhYDvkZmBtY\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount12 \"http://sonaddreess12.com\" \[\[bitcoin, 03df2462a5a2f681a3896f61964a65566ff77448be9a55a6da18506fd9c6c051c1\], \[peerplays, TEST6z33kHxQxyGvFWfpAnL3X3MvLtPEBknkNeFFJyk63PvRtaN1Xo\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount13 \"http://sonaddreess13.com\" \[\[bitcoin, 02bafba3096f546cc5831ce1e49ba7142478a659f2d689bbc70ed37235255172a8\], \[peerplays, TEST55eCWenoKmZct5YvUYv7aphMmSVkroZTJZWFHGTVj8r8bKEPMd\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount14 \"http://sonaddreess14.com\" \[\[bitcoin, 0287bcbd4f5d357f89a86979b386402445d7e9a5dccfd16146d1d2ab0dc2c32ae8\], \[peerplays, TEST5e4HXhA4yBEGzaXVyjuVabKhG1qGghi6rypvq5fLxAmU9XLRHT\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount15 \"http://sonaddreess15.com\" \[\[bitcoin, 02053859d76aa375d6f343a60e3678e906c008015e32fe4712b1fd2b26473bdd73\], \[peerplays, TEST89qMuZejYeeGvjr3bMEcGyvhD4dyUchmxbLNUBFbPodqJKJPZc\]\] true\r"

    sleep 0.5

    expect "unlocked >>> "
    send "try_create_son sonaccount16 \"http://sonaddreess16.com\" \[\[bitcoin, 03c880baffd37471f3c7e712e51b339dd08e2056757fc8499ea3d41d4fa1801247\], \[peerplays, TEST6KRpHxYJSE5vXvoeVMLbKSYnVspt2nnGV2enncRzHgLQ9dez5v\]\] true\r"

    sleep 1.0

    expect "unlocked >>> "
    send "vote_for_son sonaccount01 sonaccount01 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount02 sonaccount02 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount03 sonaccount03 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount04 sonaccount04 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount05 sonaccount05 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount06 sonaccount06 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount07 sonaccount07 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount08 sonaccount08 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount09 sonaccount09 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount10 sonaccount10 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount11 sonaccount11 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount12 sonaccount12 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount13 sonaccount13 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount14 sonaccount14 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount15 sonaccount15 true true\r"

    expect "unlocked >>> "
    send "vote_for_son sonaccount16 sonaccount16 true true\r"

EOF
}
