# MasKIT

MasKIT is an on-line tool and REST API service for pseudonymization and anonymization of Czech legal texts.
Taking a plain text as input (e.g., a letter sent by a legal authority to a citizen),
it runs external services for dependency parsing and named entity recognition and then identifies and replaces personal information in the text.

MasKIT Web Application is available at [http://quest.ms.mff.cuni.cz/maskit/](http://quest.ms.mff.cuni.cz/maskit/).

MasKIT REST API Web service is also available, with the API documentation at [http://quest.ms.mff.cuni.cz/maskit/api-reference.php](http://quest.ms.mff.cuni.cz/maskit/api-reference.php).

## License

Copyright 2023-2025 by Institute of Formal and Applied Linguistics, Faculty of Mathematics and Physics, Charles University, Czech Republic. 
The software is available under the Creative Commons [CC BY-NC-SA](https://creativecommons.org/licenses/by-nc-sa/4.0/) licence.

## Requirements

The software has been developed and tested on Linux (Ubuntu) and is run from the command line.
See [the documentation](https://ufal.mff.cuni.cz/maskit/users-manual).

## External services

MasKIT uses external services for its work:

- [UDPipe](https://github.com/ufal/udpipe/)
- [NameTag](https://github.com/ufal/nametag/)
