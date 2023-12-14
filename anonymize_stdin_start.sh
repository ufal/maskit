
echo "Anonymizing input text" >err

echo "Paní Nováková pracuje ve firmě Česká plynárenská, s.r.o." |\
./system/maskit.pl --stdin --diff --randomize --named-entities 2 --output-format txt 2>>err

echo "Anonymization finished." >>err
