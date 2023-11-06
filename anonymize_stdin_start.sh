
echo "Anonymizing input text" >err

echo "Paní Vendula Vondrušková z Vítězné ul. č. 25 a její muž Bronislav Vondruška šli každý jinam. Paní Vondrušková potkala paní Vobořilovou." |\
./system/anonymize.pl --stdin --diff --store-conllu --named-entities --output-format html 2>>err

echo "Anonymization finished." >>err
