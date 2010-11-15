usage(){
    cat << ECHO
keyword-syncer - exports and imports custom search engines in Google's Chrome browser
Usage:
    $0 [options] profile_path

Summary:
    asdf
    The profile path can be either a directory that contains a Google Chrome
    "Web Data" file, or the file itself. The file exported from this tool can be
    edited as a spreadsheet. Currently the only import options are to append to
    the existing table entries or to replace them all.
        -h           Display this information.
        -e           Export to a csv file
        -i csv_file  Import contents of a csv file
        -a           Atomic import. Nuke existing entries. (backup will be exported)

Acknowledgments:
    Copyright (c) 2010 Richard Bronosky
    Offered under the terms of the MIT License.
    http://www.opensource.org/licenses/mit-license.php
    Created while employed by CMGdigital
ECHO

    exit $1
}

export_keywords(){
	OUT="$1"
	echo -n > "$OUT"
	sqlite3 "$DB_FILE" <<- SQL > "$OUT"
	.headers ON
	.mode csv
	select * from keywords;
	SQL
}

import_keywords(){
	IN="$1"
	echo "Importing file: $IN"
	echo "DROP TABLE IF EXISTS keywordsImport;" | sqlite3 "$DB_FILE"
	# create a table (keywordsImport) like an existing table (keywords).
	echo ".schema keywords" | sqlite3 "$DB_FILE" | sed 's/TABLE "keywords"/TABLE "keywordsImport"/' | sqlite3 "$DB_FILE"
	# trim headers if needed
	TEMP=$(mktemp -t $(basename -s .sh $0))
	cat "$IN" | awk -F, 'NR==1 && $2=="short_name" && $3=="keyword" {next} {print}' > $TEMP
	# collect field list
	fields=$(
	sqlite3 "$DB_FILE" <<- SQL | sed 's/[iI][dD],//;q'
	.separator ","
	.headers ON
	INSERT INTO keywordsImport (id,short_name,keyword,favicon_url,url) values (0,0,0,0,0);
	select * from keywordsImport;
	DELETE from keywordsImport;
	SQL
	)
    # import the temporary data file
	sqlite3 "$DB_FILE" <<- SQL
	.separator ","
	.import $TEMP keywordsImport
	INSERT INTO keywords ($fields) SELECT $fields from keywordsImport;
	DROP TABLE IF EXISTS keywordsImport;
	SQL
    # remove the temporary data file
    [[ -f "$TEMP" ]] && rm "$TEMP"
}

backup_keywords(){
	OUTPUT_FILE="$PWD/keywords.$(date +%s).csv"
	echo "Creating backup file: $OUTPUT_FILE"
	export_keywords "$OUTPUT_FILE"
}

truncate_keywords(){
	echo; read -sn 1 -p "Are you sure you want to delete all existing keyword searches? [y/N] " response; echo
	if [[ $response =~ [yY] ]]; then
		echo "DELETE FROM keywords;" | sqlite3 "$DB_FILE"
	fi
}

opt_export(){
	OUTPUT_FILE="$PWD/keywords.csv"
	echo "Creating export file: $OUTPUT_FILE"
	export_keywords "$OUTPUT_FILE"
}

opt_atomic(){
	truncate_keywords
}

opt_import(){
	import_keywords "$IMPORT_FILE"
}

while getopts "eai:" opt; do
	case $opt in
		e ) # export
		operations[1]=opt_export
			;;

		a ) # atomic
		operations[3]=opt_atomic
			;;

		i ) # import
		IMPORT_FILE="$OPTARG"
		operations[2]=backup_keywords
		operations[4]=opt_import
			;;

		h|\? ) usage 1 ;;
	esac
done

DB_FILE=${!OPTIND}
[[ -d "$DB_FILE" ]] && DB_FILE="${DB_FILE%/}/Web Data"
if [[ ! -f "$DB_FILE" ]]; then
    echo "Cannot read Web Data file: $DB_FILE"
    exit 2
fi
echo "Using Web Data file: $DB_FILE"
for operation in "${operations[@]}";
do
	"${operation[@]}"
done
