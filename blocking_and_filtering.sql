-------------- UDFs ---------------

create or replace function remove_punct(titles text)
returns text
language python{
	from string import punctuation
	import re
	
	new_list = []
	for title in titles:
		title = str(title)
		new_title = re.sub(f"[{punctuation}]",'', title)
		new_list.append(new_title)
	
	return new_list
};


create or replace function subst_aliases(titles text)
returns text
language python{
	aliases = {"cannon": "canon", "canonpowershot": "canon", "eos": "canon", "usedcanon": "canon",
	"fugi": "fujifilm", "fugifilm": "fujifilm", "fuji": "fujifilm","fujufilm": "fujifilm", "general": "ge",
	"gopros": "gopro", "hikvision3mp": "hikvision", "hikvisionip": "hikvision", "bell+howell": "howell",
	"howellwp7": "howell", "minotla": "minolta", "canon&nikon": "nikon", "olympuss": "olympus", "panosonic": "panasonic",
	"pentax": "ricoh","ssamsung": "samsung", "repairsony": "sony", "elf": "elph", "s480016mp": "s4800", "vivicam": "v",
	"plus": "+", "1080p": "", "720p": ""}
	
	new_list = []
	for title in titles:
		for key, value in aliases.items():
			title = title.replace(key, value)
		new_list.append(title)
		
	return new_list
};


create or replace function find_brand(titles text)
returns text
language python{
	brands = ["aiptek", "apple", "argus", "benq", "canon", "casio", "coleman", "contour", "dahua",
	 "epson", "fujifilm", "garmin", "gopro", "hasselblad","hikvision","howell", "hp", "intova",
	 "jvc", "kodak", "leica", "lg", "lowepro","lytro", "minolta", "minox", "motorola", "mustek", "nikon",
	 "olympus", "panasonic", "pentax", "philips", "polaroid", "ricoh", "sakar", "samsung", "sanyo", "sekonic",
	 "sigma", "sony", "tamron", "toshiba","vivitar", "vtech", "wespro", "yourdeal", "ge"]
	
	brands_list = []
	
	for title in titles:
		brand_found = False
		for brand in brands:
			if brand in title:
				brands_list.append(brand)
				brand_found = True
				break
		if not brand_found:
			brands_list.append("unknown")
				
	return brands_list
};


create or replace function extract_model_from_json(extras text)
returns text
language python{
	import json
	
	models_list = []
	for data in extras:
		temp = json.loads(data)
		try:
			model = temp["model"]
		except:
			model = 'unknown'
		finally:
			models_list.append(model)
	
	return models_list
};


create or replace function find_model(titles text)
returns text
language python{
	import re
	
	p = re.compile('(\w+\d+\w*) | (\w*\d+\w+)')
	
	models_list = []
	for title in titles:
		m = p.search(title)
		
		try:
			models_list.append(m.group())
		except:
			models_list.append("unknown")
		
	return models_list
};


-------------- Blocking ---------------

alter table cameras.specs
add column brand text;

-- utilize the defined UDFs in a nested manner, in order to extract the brand
update cameras.specs 
set brand = find_brand(subst_aliases(lcase(remove_punct(title))));

-- create the table holding the brands
create table if not exists cameras.brands (
	brand_id int not null auto_increment,
	brand text not null,
	primary key (brand_id)
);

insert into cameras.brands (brand)
select distinct(brand) from cameras.specs;

-- join the two tables so as to substitute the brand with 
-- its corresponding brand_id from the brands table
alter table cameras.specs 
add column brand_id int;

alter table cameras.specs 
add foreign key (brand_id) references cameras.brands(brand_id);

update cameras.specs as s
set brand_id = (select b.brand_id from cameras.brands as b where s.brand = b.brand)
where exists (select 1 from cameras.brands as b where s.brand = b.brand);

alter table cameras.specs 
drop column brand;

--we can inspect the number of cameras per brand/ brand_id
select b.brand_id, b.brand, count(*) as count
from cameras.specs as s inner join cameras.brands as b on s.brand_id = b.brand_id 
group by b.brand_id, b.brand
order by count(*) desc;

-- Let's check the updated table
select * from cameras.specs;


-------------- Filtering ---------------

alter table cameras.specs 
add column model text;

/* firstly we use the udf (extract_model_from_json) that utilizes 
 * the model attribute of the json file */
update cameras.specs 
set model = remove_punct(lcase(extract_model_from_json(extra_info)));

-- then we use another udf (find_model) which utilizes regular expressions
update cameras.specs 
set model = find_model(subst_aliases(lcase(remove_punct(title))))
where model = 'unknown';

-- let's check the updated table
select * from cameras.specs;

-- check how many unknown models we obtain
select count(*) from cameras.specs where model = 'unknown';

/* with the below query we conclude that the problematic site 
 * is that of the Alibaba, as more than the one fourth of its 
 * cameras give an unknown model */
select site, count(*) 
from cameras.specs 
where model = 'unknown' 
group by site 
order by 2 desc;


-------------- Matching ---------------

/* The below query contains the matches (brand_id=4 represents the unknown brand) found
 * by our blocking and filtering procedures, further enhanced with the matches obtained 
 * by the labels table (i.e. the csv file). Note tha we utilize the least and greatest 
 * keywords in order to remove duplicates in cases where a pair of cameras appears in 
 * both normal and reverse order.
 */

with custom_matches as (
	select distinct least(s1.spec_id, s2.spec_id) as left_spec_id,
			greatest(s1.spec_id, s2.spec_id) as right_spec_id
	from cameras.specs as s1 
	inner join cameras.specs as s2
		on s1.brand_id = s2.brand_id
		and s1.model = s2.model
	where s1.spec_id <> s2.spec_id
		and s1.brand_id <> 4
		and s1.model <> 'unknown'
)
select left_spec_id, right_spec_id
from custom_matches
union
select distinct least(left_spec_id, right_spec_id), greatest(left_spec_id, right_spec_id)
from cameras.labels 
where label = 1;



/* A query containing the non-matched cameras by removing accordingly
 * the matched cameras from both our custom matches and those obtained 
 * from the labels table.
 */

select distinct spec_id 
from cameras.specs
except(
	select left_spec_id from cameras.labels where label = 1
	union 
	select right_spec_id from cameras.labels where label = 1
)
except (
	select s1.spec_id as left_spec_id 
	from cameras.specs as s1 
	inner join cameras.specs as s2
		on s1.brand_id = s2.brand_id
		and s1.model = s2.model
	where s1.spec_id <> s2.spec_id
		and s1.brand_id <> 4
		and s1.model <> 'unknown'
);

