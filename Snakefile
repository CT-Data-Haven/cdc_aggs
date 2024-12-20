from pathlib import Path


#### HELPERS FOR RELEASE METADATA ----
def read_year(year_file):
    with open(year_file, "r") as f:
        year = f.read().strip()
    return year


def release_files(year_file):
    year = read_year(year_file)
    cdc_files = (
        f"output_data/cdc_health_all_lvls_nhood_{year}.rds",
        f"output_data/cdc_health_all_lvls_wide_{year}.csv",
    )
    return cdc_files


# get places release year from api
rule release_meta:
    output:
        year="utils/release_year.txt",
    script:
        "prep_scripts/get_release_meta.sh"

rule download_meta:
    output:
        xwalk = 'utils/tract_to_legislative.rds',
        headings = 'utils/cdc_indicators.txt',
        regs = 'utils/reg_puma_list.rds',
    script:
        'prep_scripts/download_meta.sh'


# rule tract2town:
#     output:
#         "utils/tract_to_town.rds",
#     script:
#         "prep_scripts/tract10_to_town.R"


rule calc_cdc:
    input:
        year_file=rules.release_meta.output.year,
        regs=rules.download_meta.output.regs,
        headings=rules.download_meta.output.headings,
        # tract2town=rules.tract2town.output,
    params:
        year=read_year(rules.release_meta.output.year),
    output:
        release_files(rules.release_meta.output.year),
    script:
        "analysis/calc_cdc_aggs.R"


rule upload_gh:
    input:
        rules.calc_cdc.output,
    output:
        touch(".uploaded"),
    params:
        year=read_year(rules.release_meta.output.year),
    shell:
        '''
        bash ./prep_scripts/upload_to_gh.sh {params.year} {input}
        '''



rule all:
    input:
        rules.calc_cdc.output,
        rules.upload_gh.output,
    default_target: True
