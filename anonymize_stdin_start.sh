
echo "Anonymizing input text" >err

echo "Paní Vendula Vondrušková z Vítězné ul. č. 25 a její muž Bronislav Vondruška." |\
./system/anonymize.pl --stdin --diff --output-format html 2>>err

echo "Anonymization finished." >>err
