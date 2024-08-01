
echo "Anonymizing input text" >err

echo -e "v Ostravě – Kunčicích, na ulici Frýdecké č. 426/28, na základě předchozí dohody" |\
./system/maskit.pl --stdin --diff --randomize --named-entities 2 --output-format txt --logging-level 0 --log-states NT,UN --store-format conllu 2>>err

echo "Anonymization finished." >>err
