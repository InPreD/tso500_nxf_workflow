process UPDATE_SMALL_VARIANT_VCF_LIST {
    tag "$id"
    label 'process_low'

    container 'ubuntu:24.04'

    input:
    tuple val(id), path(results)
    path vcf_list

    output:
    tuple val(id), path("TSO500_vcf_list.tsv") , emit: tsv
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def controlPrefix = "IPC"
    def tmp_list = "TSO500_vcf_list.tsv.tmp"
    """
    echo "[INFO] generating updated temporary VCF list with VCF files from run ${id}"
    cat ${vcf_list} <(ls -1 ${results}/*/*/*_MergedSmallVariants.genome.vcf \\
        | sed "s/\\(.*\\/\\)\\(.*\\)\\(_MergedSmallVariants.genome.vcf\\)/\\\\1\\\\2\\\\3	\\\\2/" \\
        | awk 'OFS="\t" {print \$1, substr(\$2, 13, 1)}') \\
        > ${tmp_list}

    BAD_SAMPLE_TYPE_CODES=()
    for SAMPLE_VCF in `ls -1 ${results}/*/*/*_MergedSmallVariants.genome.vcf`
    do
      SAMPLE_ID=`echo \${SAMPLE_VCF} | sed "s/\\(.*\\/\\)\\(.*\\)\\(_MergedSmallVariants.genome.vcf\\)/\\\\2/"`
      SAMPLE_TYPE_CODE=`echo \${SAMPLE_ID} | awk '{print substr(\$1, 13, 1)}'`

      # check that sample type code is not an empty string
      if [[  -z "\${SAMPLE_TYPE_CODE// }" ]]
      then
          echo "[ERR] \\\$SAMPLE_TYPE_CODE cannot be empty! Check that sample IDs follow inpred nomenclature"
          echo "[ERR] Exiting now..."
          exit 1
      fi

      PATIENT_ID=\${SAMPLE_ID%%-*}
      PATIENT_SAMPLE_COUNT=`grep "\${PATIENT_ID}" ${tmp_list} | wc -l`

      SAMPLE_TYPE_CODE_OK_STRING="[OK]"
      if [ \${SAMPLE_TYPE_CODE} != "T" ] && [ \${SAMPLE_TYPE_CODE} != "N" ]
      then
        SAMPLE_TYPE_CODE_OK_STRING="[not \"T\" or \"N\"!]"
        echo "[WARN] Unknown sample type code '\$SAMPLE_TYPE_CODE' encountered!"
        echo "[WARN] Only sample type codes 'T' and 'N' are allowed in the VCF list file!"
        case \${SAMPLE_TYPE_CODE} in
            ["P","p","R","r","D","d","C","L","M","X"])
            echo "[INFO] Replacing sample type code '\$SAMPLE_TYPE_CODE' with value 'T' "
            sed -i 's/[P,p,R,r,D,d,C,L,M,X]\$/T/' ${tmp_list}
            SAMPLE_TYPE_CODE="T"
            SAMPLE_TYPE_CODE_OK_STRING="[OK]"
            ;;
        *)
            echo "[WARN] You need to manually edit ${tmp_list} by replacing the unknown sample type code '\$SAMPLE_TYPE_CODE' with either 'T' or 'N' "
            BAD_SAMPLE_TYPE_CODES+=(\${SAMPLE_TYPE_CODE})
            ;;
        esac
      fi

      PATIENT_SAMPLE_COUNT_OK_STRING="[OK]"
      if [ \${PATIENT_SAMPLE_COUNT} -ne 1 ]
      then
        PATIENT_SAMPLE_COUNT_OK_STRING="[not 1!]"
      fi

      echo "[INFO] sample VCF: \${SAMPLE_VCF}"
      echo "[INFO] sample ID: \${SAMPLE_ID}"
      echo "[INFO] sample type code: \${SAMPLE_TYPE_CODE} \${SAMPLE_TYPE_CODE_OK_STRING}"
      echo "[INFO] patient ID: \${PATIENT_ID}"
      echo "[INFO] patient sample count: \${PATIENT_SAMPLE_COUNT} \${PATIENT_SAMPLE_COUNT_OK_STRING}"
    done

    if [ \${#BAD_SAMPLE_TYPE_CODES[@]} -gt 0 ]
    then
      echo "[ERR] The following unknown SAMPLE_TYPE_CODE(s) exist in ${tmp_list}:"
      echo "\${BAD_SAMPLE_TYPE_CODES[@]}"
      echo "[ERR] You need to manually edit ${tmp_list} to have only sample codes 'T' or 'N' "
      echo "[ERR] Exiting now..."
      exit 1
    fi

    echo "[INFO] checking for control samples in temporary VCF list and removing them"
    if grep -q "${controlPrefix}" "${tmp_list}"; then
        echo "[WARN] The following sample(s) will not be entered into the VCF file because they are suspected test/controls..."
        grep "${controlPrefix}" ${tmp_list}
        sed -i "/${controlPrefix}/d" ${tmp_list}
    fi

    cat ${tmp_list} | sort | uniq > ${tmp_list}.uniq
    mv ${tmp_list}.uniq TSO500_vcf_list.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk -W version 2>&1 | grep awk | sed 's/mawk //')
    END_VERSIONS
    """

    stub:
    def tmp_list = "TSO500_vcf_list.tsv.tmp"
    """
    touch ${tmp_list}
    mv ${tmp_list} TSO500_vcf_list.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: stub
    END_VERSIONS
    """
}
