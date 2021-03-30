create table cameras.labels (
	left_spec_id varchar(50),
	right_spec_id varchar(50),
	label tinyint,
	foreign key (left_spec_id) references cameras.specs(spec_id),
	foreign key (right_spec_id) references cameras.specs(spec_id)
);

copy offset 2 into cameras.labels from 'C:\\sigmod_medium_labelled_dataset.csv' using delimiters ',', '\n', '"';

select * from cameras.labels sample 20;
