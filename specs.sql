create table cameras.specs from loader data_loader('C:\\2013_camera_specs');

alter table cameras.specs add primary key(spec_id);

select * from cameras.specs sample 20;

