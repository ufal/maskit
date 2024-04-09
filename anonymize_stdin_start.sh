
echo "Anonymizing input text" >err

echo -e "Paní Nováková pracuje ve firmě Česká plynárenská, s.r.o. Pan Novák zůstává v souvislosti s prací v domě.\nJsou manželé." |\
./system/maskit.pl --stdin --diff --randomize --named-entities 2 --output-format txt --store-format conllu 2>>err

echo "Anonymization finished." >>err
