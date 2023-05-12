import datetime
import argparse
import sys
import pandas as pd

# read input parameters
parser=argparse.ArgumentParser(description='Generate SampleSheet for TSO500 LocalApp analysis for a given sequencing run, index_type and index_length.')
parser.add_argument('-r', '--run-id', help='ID string of the sequencing run for which a samplesheet should be generated.', required=True, type=str)
parser.add_argument('-t', '--index-type', help='Type of indexes, allowed values are \'dual\' and \'simple\'.', required=True, type=str)
parser.add_argument('-x', '--index-length', help='Index sequence length. Supported lengths 8 and 10 for dual indexes and 8 for simple indexes.', required=True, type=int)
parser.add_argument('-n', '--investigator-name', help='Investigator name to be passed into samplesheet header, cannot contain a comma. [Default: \'\']', default='', type=str)
parser.add_argument('-e', '--experiment-name', help='Experiment name to be passed into samplesheet header, cannot contain a comma. [Default: \'\']', default='', type=str)
parser.add_argument('-i', '--input-info-file', help='Table with info about samples processed in one go.', required=True, type=str)
parser.add_argument('-s', '--separator', help='Field separator used in input-info-file.', required=True, type=str)
parser.add_argument('-1', '--read-length-1', help='Length of sequenced forward reads. [Default: \'101\']', default='101', type=str)
parser.add_argument('-2', '--read-length-2', help='Length of sequenced reverse reads. [Default: \'101\']', default='101', type=str)
parser.add_argument('-3', '--adapter-read-1', help='Sequence of read 1 adapter, will be used by BCL convert. [Default=\'\']', required=True, type=str)
parser.add_argument('-4', '--adapter-read-2', help='Sequence of read 2 adapter, will be used by BCL convert. [Default=\'\']', required=True, type=str)
parser.add_argument('-b', '--adapter-behavior', help='Setting AdapterBehavior value that will be used by BCL convert. [Default=\'trim\']', default='trim', type=str)
parser.add_argument('-l', '--minimum-trimmed-read-length', help='Setting MinimumTrimmedReadLength value that will be used by BCL convert. [Default=35]', default=35, type=int)
parser.add_argument('-m', '--mask-short-reads', help='Setting MaskShortReads value that will be used by BCL convert. [Default=22]', default=22, type=int)
parser.add_argument('-o', '--override-cycles', help='Setting OverrideCycles value that will be used by BCL convert. [Default=\'\']', required=True, type=str)
parser.add_argument('-S', '--samplesheet-version', help='Specify sample sheet version. [Default=\'v1\']', default='v1', type=str)

# index length == 8
#"AdapterRead1,AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"
#"AdapterRead2,AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT"
#"OverrideCycles,U7N1Y93;I8;I8;U7N1Y93"

# index length == 10
#"AdapterRead1,CTGTCTCTTATACACATCTCCGAGCCCACGAGAC"
#"AdapterRead2,CTGTCTCTTATACACATCTGACGCTGCCGACGA"
#"OverrideCycles,U7N1Y93;I10;I10;U7N1Y93"

args=parser.parse_args()

index_length                = args.index_length
investigator_name           = args.investigator_name
experiment_name             = args.experiment_name
input_info_file             = args.input_info_file
separator                   = args.separator
read_length_1               = args.read_length_1
read_length_2               = args.read_length_2
adapter_read_1              = args.adapter_read_1
adapter_read_2              = args.adapter_read_2
adapter_behavior            = args.adapter_behavior
minimum_trimmed_read_length = str(args.minimum_trimmed_read_length)
mask_short_reads            = str(args.mask_short_reads)
override_cycles             = args.override_cycles
samplesheet_version         = args.samplesheet_version

# check input values

if   (args.index_type.lower() == "dual"):
	dual_indexes = True
elif (args.index_type.lower() == "simple"):
	dual_indexes = False
else:
	sys.exit("Unsupported value of index_type=\'"+args.index_type+"\' provided.")	


if not (args.index_length == 8) and not (args.index_length == 10):
	sys.exit("Unsupported value of index_length=\'"+args.index_length+"\' provided.")
elif not dual_indexes and (args.index_length == 10):
	sys.exit("Unsupported value of index_length=\'"+args.index_length+"\' for simple indexes provided.")



#TODO: implement v2 format and remove this condition
if (samplesheet_version == 'v2'):
	sys.exit("Not implemented yet.")





def assign_indexes(dual_indexes, index_length):
	
	# based on dual_indexes and index_length values 
	# determine which file to take the index data from
	filename=""
	if dual_indexes:
		if (index_length == 8):
			filename = "../data/TSO500_NextSeq_dual_indexes.tsv"
		elif (index_length == 10):
			filename = "../data/TSO500_NovaSeq_dual_indexes.tsv"
		else:
			sys.exit("Unsupported index_length="+str(index_length)+" for dual_indexes=True")
	else:
		if (index_length == 8):
			filename = "../data/TSO500_NextSeq_simple_indexes_legacy.tsv"
		else:
			sys.exit("Unsupported index_length="+str(index_length)+" for dual_indexes=False")
		
	# read file info into pandas dataframe i_df
	i_df = pd.read_csv(filename, sep='\t', comment='#', header=0, na_filter=False)
	i_df = i_df.reset_index()
		
	# iterate through rows and for each row create a record in the indices dictionary
	indexes=dict()		

	if dual_indexes:
		for index, row in i_df.iterrows():
			indexes[row['Index_ID']]=dict()
			indexes[row['Index_ID']]['index']  = row['index']
			indexes[row['Index_ID']]['index2'] = row['index2']
	else:
		for index, row in i_df.iterrows():
			indexes[row['Index_ID']]=dict()
			indexes[row['Index_ID']]['index']        = row['index']
			indexes[row['Index_ID']]['I7_Index_ID']  = row['I7_Index_ID']
			indexes[row['Index_ID']]['index2']       = row['index2']
			indexes[row['Index_ID']]['I5_Index_ID']  = row['I5_Index_ID']
			
	return(indexes)
	

	
def print_header_section_v1(investigator_name, experiment_name):
	now = datetime.datetime.now()
	print("[Header]")
	print("Investigator Name,"+investigator_name)
	print("Experiment Name,"+experiment_name)
	print("Date,"+now.strftime('%d/%m/%Y'))
	print("")

def print_reads_section_v1():
	print("[Reads]")
	print(read_length_1)
	print(read_length_2)
	print("")

def print_settings_section_v1():
	print("[Settings]")
	print("AdapterRead1,"+ adapter_read_1)
	print("AdapterRead2,"+ adapter_read_2)
	print("AdapterBehavior,"+ adapter_behavior)
	print("MinimumTrimmedReadLength,"+ minimum_trimmed_read_length)
	print("MaskShortReads,"+ mask_short_reads)
	print("OverrideCycles,"+ override_cycles)
	print("")



# small helper functions for print_data_section_v1 defined below

def provided(s):

	if (str(s) == ""):
		return False
	else:
		return True

def index_exists(index, indexes):

	exists = False

	for b in indexes.keys():
		if (indexes[b]['index'] == index):
			exists = True

	return exists

def barcode_exists(barcode, indexes):

	exists = False
	
	for b in indexes.keys():
		if (b == barcode):
			exists = True
			
	return exists

def i7_index_id_exists(i7_index_id, indexes):

	exists = False
	
	for b in indexes.keys():
		if (indexes[b]['I7_Index_ID'] == i7_index_id):
			exists = True
	
	return exists
	
def paired_barcode_index(barcode, index, indexes):

	paired = False

	if (indexes[barcode]['index'] == index):
		paired = True

	return paired

def paired_i7_index_id_index(i7_index_id, index, indexes):

	paired = False

	barcode = ""
	
	for b in indexes.keys():
		if (indexes[b]['I7_Index_ID'] == i7_index_id):
			barcode = b

	if (indexes[barcode]['index'] == index):
		paired = True

	return paired




def print_data_section_v1(dual_indexes, index_length, indexes, input_info_file, separator):

	info_df = pd.read_csv(input_info_file, sep=separator, comment='#', header=0)
	info_df = info_df.fillna('')
	info_df = info_df.reset_index()

	info = dict()

	if dual_indexes:
		# generate dictionary of indices used in the current sequencing run coupled with other info from input info file

		for index, row in info_df.iterrows():
		
			if (str(row['run_id']) == args.run_id):
			# select only samples from a run with the given run_id
				
				sample_id = row['sample_id']
				molecule  = row['molecule'].upper()[0]
				
				barcode = ""
				index = ""
				index2 = ""
			
				# assign barcode, index, index2 according to provided indexes dictionary
				if    provided(row['barcode']) and (not provided(row['index'])):
				
					#check whether barcode is a key in indexes
					if barcode_exists(row['barcode'], indexes):
					
						# assign barcode and use it to identify index, index2
						barcode = row['barcode']
						index   = indexes[barcode]['index']
						index2  = indexes[barcode]['index2']
					else:
						sys.exit("Barcode \'"+row['barcode']+"\' is not present in indexes." )
					
				elif (not provided(row['barcode'])) and  provided(row['index']):
				
					#check whether index is present in indexes[*]['index']
					if index_exists(row['index'], indexes):
					
						# assign index and use it to identify barcode and index2
						for b in indexes.keys():
							if (indexes[b]['index'] == row['index']):
								barcode = b
						
						index  = row['index']
						index2 = indexes[barcode]['index2']
					else:
						sys.exit("Index \'"+row['index']+"\' is not present in indexes.")

				elif  provided(row['barcode']) and  provided(row['index']):
				
					# check whether barcode and index are stored in the same item in dict indexes
					if barcode_exists(row['barcode'], indexes) and index_exists(row['index'], indexes) and paired_barcode_index(row['barcode'], row['index'], indexes):
					
						#assign barcode and index and identify index2
						barcode = row['barcode']
						index   = row['index']
						index2  = indexes[barcode]['index2']
						
					else:
						sys.exit("Provided barcode and index are not paired in indexes.")
						
				else:
					# none of the two pieces of info are provided for the sample (neither barcode nor index) thus sys.exit()
					sys.exit("Neither barcode nor index is provided for sample \'"+sample_id+"\' in the input info file "+ input_info_file)
				
				
				#store the sample info in dictionary info, if there is no other record present for sample_id
				if not (sample_id in info.keys()):
					info[sample_id] = dict()
					info[sample_id]['barcode']  = barcode
					info[sample_id]['index']    = index
					info[sample_id]['index2']   = index2
					
					if   (molecule == 'D'):
						info[sample_id]['molecule'] = 'DNA'
					elif (molecule == 'R'):
						info[sample_id]['molecule'] = 'RNA'
				else:
					sys.exit("info[sample_id] already exists for sample_id="+sample_id)

				
			
		# print out data header
		print("[Data]")
		print("Sample_ID,Sample_Type,Pair_ID,Index_ID,index,index2")
		
		# iterate through all the sample_ids and print out a samplesheet line for each of them
		for sample_id in info.keys():
		
			samplesheet_line = ','.join(( sample_id, info[sample_id]['molecule'], sample_id, info[sample_id]['barcode'], info[sample_id]['index'], info[sample_id]['index2'] ))
			
			print(samplesheet_line)
			
	else:
	
		# generate dictionary of indices used in the current sequencing run coupled with other info from input info file

		for index, row in info_df.iterrows():
		
			if (str(row['run_id']) == args.run_id):
			# select only samples from a run with the given run_id
				
				sample_id = row['sample_id']
				molecule  = row['molecule'].upper()[0]
				
				index       = ""
				I7_Index_ID = ""
				index2      = ""	
				I5_Index_ID = ""
				barcode     = ""

				if    provided(row['barcode']) and (not provided(row['index'])):

					#check whether barcode is present in indexes[*]['I7_Index_ID']
					if i7_index_id_exists(row['barcode'], indexes):
						
						# assign I7_Index_ID and use it to identify index, index2, I5_Index_ID using barcode
						for b in indexes.keys():
							if (indexes[b]['I7_Index_ID'] == row['barcode']):
								barcode = b
						
						index       = indexes[barcode]['index']
						I7_Index_ID = row['barcode']
						index2      = indexes[barcode]['index2']
						I5_Index_ID = indexes[barcode]['I5_Index_ID']
	
					else:
						sys.exit("Barcode \'"+row['barcode']+"\' is not present as a value of any indexes[*]['I7_Index_ID']." )
						
				elif (not provided(row['barcode'])) and  provided(row['index']):
				
					#check whether index is present in indexes[*]['index']
					if index_exists(row['index'], indexes):
					
						# assign index and use it to identify index2, I7_Index_ID, I5_Index_ID using barcode
						for b in indexes.keys():
							if (indexes[b]['index'] == row['index']):
								barcode = b
						
						index       = row['index']
						I7_Index_ID = indexes[barcode]['I7_Index_ID']
						index2      = indexes[barcode]['index2']
						I5_Index_ID = indexes[barcode]['I5_Index_ID']
						
					else:
						sys.exit("Index \'"+row['index']+"\' is not present as a value of any indexes[*]['index'].")


				elif  provided(row['barcode']) and  provided(row['index']):
				
					# check whether barcode and index are stored in the same item in dict indexes
					if i7_index_id_exists(row['barcode'], indexes) and index_exists(row['index'], indexes) and paired_i7_index_id_index(row['barcode'], row['index'], indexes):
					
						# assign index and I7_Index_ID and use those to identify index2 and I5_Index_ID using barcode
						for b in indexes.keys():
							if (indexes[b]['index'] == row['index']):
								barcode = b
						
						index       = row['index']
						I7_Index_ID = row['barcode']
						index2      = indexes[barcode]['index2']
						I5_Index_ID = indexes[barcode]['I5_Index_ID']
						
					else:
						sys.exit("Provided barcode and index are not paired in indexes.")


				else:
					# none of the two pieces of info are provided for the sample (neither barcode nor index) thus sys.exit()
					sys.exit("Neither barcode nor index is provided for sample \'"+sample_id+"\' in the input info file "+ input_info_file)
						


				#store the sample info in dictionary info, if there is no other record present for sample_id
				if not (sample_id in info.keys()):
					info[sample_id] = dict()
					info[sample_id]['index']       = index
					info[sample_id]['I7_Index_ID'] = I7_Index_ID
					info[sample_id]['index2']      = index2
					info[sample_id]['I5_Index_ID'] = I5_Index_ID
					
					if   (molecule == 'D'):
						info[sample_id]['molecule'] = 'DNA'
					elif (molecule == 'R'):
						info[sample_id]['molecule'] = 'RNA'
				else:
					sys.exit("info[sample_id] already exists for sample_id="+sample_id)

		
		# print out data header
		print("[Data]")
		print("Sample_ID,Sample_Type,Pair_ID,index,I7_Index_ID,index2,I5_Index_ID")
		
		# iterate through all the sample_ids and print out a samplesheet line for each of them
		for sample_id in info.keys():
		
			samplesheet_line = ','.join(( sample_id, info[sample_id]['molecule'], sample_id, info[sample_id]['index'], info[sample_id]['I7_Index_ID'], info[sample_id]['index2'], info[sample_id]['I5_Index_ID'] ))
	
			print(samplesheet_line)
		




indexes=assign_indexes(dual_indexes, index_length)
#print(indexes)

if (samplesheet_version == 'v1'):
	print_header_section_v1(investigator_name, experiment_name)
	print_reads_section_v1()
	print_settings_section_v1()
	print_data_section_v1(dual_indexes, index_length, indexes, input_info_file, separator)
elif (samplesheet_version == 'v2'):
	sys.exit("Not implemented yet")
else:
	sys.exit("Samplesheet version "+samplesheet_version+" is not supported at the moment")
