
echo "Anonymizing input text" >err

echo "Paní Nováková bydlí na Nábřeží Kapitána Jaroše 25, Praha 7 - Holešovice, její muž, pan Novák, bydlí v ulici Jugoslávských partizánů 18." |\
./system/maskit.pl --stdin --diff --randomize --named-entities 2 --output-format txt 2>>err

echo "Anonymization finished." >>err
