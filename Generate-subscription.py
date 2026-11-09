import json
import os
import json5

all_configs = ["MITM-DomainFronting-fragA.jsonc", "MITM-DomainFronting-fragB.jsonc", "MITM-DomainFronting-oob.jsonc"]
output_path = os.path.join('Subscription', 'MITM-DomainFronting.json')

all_j = []
for config in all_configs:
    with open(config) as config_file:
        all_j.append(json5.load(config_file))

json.dump(all_j, open(output_path, "w"), indent=4)
print("done")
