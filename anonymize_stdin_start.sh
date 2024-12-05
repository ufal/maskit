
echo "Anonymizing input text" >err

echo -e "v Ostravě – Kunčicích, na ulici Frýdecké č. 426/28, na základě předchozí dohody" |\
./system/maskit.pl --stdin --diff --randomize --url-udpipe="https://lindat.mff.cuni.cz/services/udpipe/api" --url-nametag="https://lindat.mff.cuni.cz/services/nametag/api" --named-entities 2 --output-format txt --logging-level 0 --log-states NT,UN --store-format conllu 2>>err

echo "Anonymization finished." >>err
