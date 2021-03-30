create or replace loader data_loader(dir string) language python {
	import os
	import json
		
	for dirpath, _, files in os.walk(dir):
    	for file in files:
        	if file.endswith('.json'):
            	
        		website = dirpath.split("\\")[-1]
            	file_id = file.split(".")[0]

            	record_dict = {"spec_id": website + "//" + file_id,
                            	"site": website}
        		
            	with open(os.path.join(dirpath, file)) as file_data:
                	data = json.load(file_data)

                	record_dict['title'] = data['<page title>']
                	del data['<page title>']
                	
                	# serializing the rest of the data
                	record_dict['extra_info'] = json.dumps(data)
                	                	
				_emit.emit(record_dict)
        		
};


