#!/usr/bin/env bash
set -euo pipefail

# Summarize total and mapped reads from every BAM file in this script's folder.
# Requires: samtools

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${SCRIPT_DIR}/mapping_stats.tsv"

if ! command -v samtools >/dev/null 2>&1; then
    echo "ERROR: samtools tidak ditemukan. Aktifkan environment yang memiliki samtools." >&2
    exit 1
fi

shopt -s nullglob
bam_files=("${SCRIPT_DIR}"/*.bam)

if (( ${#bam_files[@]} == 0 )); then
    echo "ERROR: Tidak ada file .bam di folder ${SCRIPT_DIR}" >&2
    exit 1
fi

# Kolom: sample, total reads, mapped reads, unmapped reads, mapped percentage
printf "Sample\tTotal_reads\tMapped_reads\tUnmapped_reads\tPercentage_reads_mapped\n" > "$OUTPUT"

for bam in "${bam_files[@]}"; do
    sample="$(basename "$bam" .bam)"
    echo "Processing: ${sample}"

    # flagstat reports QC-passed counts in column 1 and QC-failed counts in column 3.
    # Sum both so the summary includes all reads reported by flagstat.
    counts="$(samtools flagstat "$bam" | awk '
        /in total/  { total = $1 + $3 }
        /^[0-9]+ \+ [0-9]+ mapped \(/ { mapped = $1 + $3 }
        END {
            if (total == "" || mapped == "") exit 1
            printf "%.0f\t%.0f", total, mapped
        }
    ')"

    IFS=$'\t' read -r total mapped <<< "$counts"
    unmapped=$(( total - mapped ))
    percentage="$(awk -v m="$mapped" -v t="$total" 'BEGIN {
        if (t > 0) printf "%.2f", (m / t) * 100
        else printf "NA"
    }')"

    printf "%s\t%s\t%s\t%s\t%s\n" \
        "$sample" "$total" "$mapped" "$unmapped" "$percentage" >> "$OUTPUT"
done

echo
echo "Selesai. Hasil tersimpan di: ${OUTPUT}"
echo "Persentase mapped dihitung sebagai (Mapped_reads / Total_reads) x 100."
