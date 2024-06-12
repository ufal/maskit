
echo "Anonymizing errors_by_MK.txt" >err

for FILE in data/errors_by_MK.txt; do

  echo >>err
  echo "Anonymizing input text $FILE" >>err
  echo >>err

  cat $FILE |\
  ./system/maskit.pl --input-file $FILE --input-format txt --diff --named-entities 2 --output-format txt --store-format conllu 2>>err

done

echo
echo "Anonymization of the data finished." >>err
