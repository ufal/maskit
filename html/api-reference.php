<?php $main_page=basename(__FILE__); require('header.php') ?>

<div class="dropdown pull-right" style='margin-left: 10px; margin-bottom: 10px'>
  <button class="btn btn-default dropdown-toggle" type="button" id="tocDropdown" data-toggle="dropdown"><span class="fa fa-bars"></span> Table of Contents <span class="caret"></span></button>
  <ul class="dropdown-menu dropdown-menu-right" aria-labelledby="tocDropdown">
    <li><a href="#api_reference">API Reference</a></li>
    <li><a href="#process"><span class="fa fa-caret-right"></span> <code>process</code></a></li>
    <li class="divider"></li>
    <li><a href="#using_curl">Accessing API using Curl</a></li>
  </ul>
</div>
<?php echo $lang[$currentLang]['api_service_url']; ?>
<code>http(s)://quest.ms.mff.cuni.cz/maskit/api/</code>.</p>


          <?php
            if ($currentLang == 'cs') {
          ?>
    <div><?php require('licence_cs.html') ?></div>
          <?php
            } else {
          ?>
    <div><?php require('licence_en.html') ?></div>
          <?php
            }
          ?>

          <?php
            if ($currentLang == 'cs') {
          ?>
    <div><?php require('api-reference_cs.html') ?></div>
          <?php
            } else {
          ?>
    <div><?php require('api-reference_en.html') ?></div>
          <?php
            }
          ?>

<?php require('footer.php') ?>
