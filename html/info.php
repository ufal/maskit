<?php $main_page=basename(__FILE__); require('header.php') ?>

<?php
  if ($currentLang == 'cs') {
?>
    <div style="margin: 5px"><?php require('about_cs.html') ?></div>
<?php
  } else {
?>
    <div style="margin: 5px"><?php require('about_en.html') ?></div>
<?php
  }
?>

<div class="panel panel-info">
  <div class="panel-heading">Basic info</div>
  <table class="table table-striped table-bordered">
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_authors']; ?></th>
      <td>Jiří Mírovský, Barbora Hladká</td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_homepage']; ?></th>
      <td><a href="http://ufal.mff.cuni.cz/maskit/" target="_blank">http://ufal.mff.cuni.cz/maskit/</a></td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_repository']; ?></th>
      <td><a href="https://github.com/ufal/maskit" target="_blank">https://github.com/ufal/maskit</a></td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_development_status']; ?></th>
      <td><?php echo $lang[$currentLang]['info_basic_development_status_development']; ?></td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_OS']; ?></th>
      <td>Linux</td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_licence']; ?></th>
      <td><a href="http://creativecommons.org/licenses/by-nc-sa/4.0/" target="_blank">CC BY-NC-SA</a></td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_contact']; ?></th>
      <td><a href="mailto:mirovsky@ufal.mff.cuni.cz">mirovsky@ufal.mff.cuni.cz</a></td>
  </tr>
  </table>
</div>

<?php require('footer.php') ?>
