# Cameras-Entity-Resolution

This project is implementing a part of the SIGMOD 2020 programming contest: http://www.inf.uniroma3.it/db/sigmod2020contest/index.html

Storing and processing the data is performed using MonetDB as the main database, along with the help of Python `User Defined Functions (UDFs)`.

More specifically, after downloading and storing the dataset, the `Blocking` and `Filtering` processes are implemented, in order to split the data into groups of possible pairs of matching objects. This process is the core part of the `Entity Resolution` procedure.
