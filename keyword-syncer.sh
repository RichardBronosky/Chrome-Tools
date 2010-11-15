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
	echo "import file: $IN"
	echo "DROP TABLE IF EXISTS keywordsInput;" | sqlite3 "$DB_FILE"
	# create a table (keywordsInput) like an existing table (keywords).
	echo ".schema keywords" | sqlite3 "$DB_FILE" | sed 's/TABLE "keywords"/TABLE "keywordsInput"/' | sqlite3 "$DB_FILE"
	# trim headers if needed
	TEMP=$(mktemp -t $(basename -s .sh $0))
	cat "$IN" | awk -F, 'NR==1 && $2=="short_name" && $3=="keyword" {next} {print}' > $TEMP
	echo "temp file: $TEMP"
	# collect field list
	fields=$(
	sqlite3 "$DB_FILE" <<- SQL | sed 's/[iI][dD],//;q'
	.separator ","
	.headers ON
	INSERT INTO keywordsInput (id,short_name,keyword,favicon_url,url) values (0,0,0,0,0);
	select * from keywordsInput;
	DELETE from keywordsInput;
	SQL
	)
	echo "fields: $fields"
	sqlite3 "$DB_FILE" <<- SQL
	.separator ","
	.import $TEMP keywordsInput
	INSERT INTO keywords ($fields) SELECT $fields from keywordsInput;
	DROP TABLE IF EXISTS keywordsInput;
	SQL
}

backup_keywords(){
	DATE=$(date +%s)
	OUT="$PWD/keywords.$DATE.csv"
	export_keywords "$OUT"
	echo "Created backup file: $OUT"
}

truncate_keywords(){
	echo; read -sn 1 -p "Are you sure you want to delete all existing keyword searches? [y/N] " response; echo
	if [[ $response =~ [yY] ]]; then
		echo "DELETE FROM keywords;" | sqlite3 "$DB_FILE"
	fi
}

opt_export(){
	OUT="$PWD/keywords.csv"
	export_keywords "$OUT"
	echo "Created export file: $OUT"
}

opt_atomic(){
	truncate_keywords
}

opt_import(){
	import_keywords "$IN"
}

opt_count=0
while getopts "eai:" opt; do
	case $opt in
		e  ) # export
		operations[1]=opt_export
			((opt_count++))
			;;

		a  ) # atomic
		operations[3]=opt_atomic
			((opt_count++))
			;;

		i  ) # import
		IN="$OPTARG"
		operations[2]=backup_keywords
		operations[4]=opt_import
			((opt_count++))
			;;

		\? ) usage 1 ;;
	esac
done

shift $opt_count
DB_FILE=$2
echo db file: $DB_FILE
for operation in "${operations[@]}";
do
	"${operation[@]}"
done
