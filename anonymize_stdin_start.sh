
echo "Anonymizing input text" >err

echo "Paní Vendula Vondrušková z Vítězné ul. č. 25 a její muž Bronislav Vondruška šli každý jinam. Paní Vondrušková potkala paní Vobořilovou." |\
./system/maskit.pl --stdin --diff --store-conllu --randomize --named-entities 2 --output-format html 2>>err

echo "Anonymization finished." >>err
