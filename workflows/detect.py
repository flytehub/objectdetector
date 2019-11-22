from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import urllib2
import six

from workflows import download
from flytekit.common import utils
from flytekit.sdk.tasks import python_task, outputs, inputs
from flytekit.sdk.types import Types
from flytekit.sdk.workflow import workflow_class, Output, Input

MIN_SCORE=0.2
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.64 Safari/537.11',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Charset': 'ISO-8859-1,utf-8;q=0.7,*;q=0.3',
    'Accept-Encoding': 'none',
    'Accept-Language': 'en-US,en;q=0.8',
    'Connection': 'keep-alive'
}

# todo add cache
@inputs(url=Types.String)
@outputs(result=Types.String, parsed_image=Types.Blob)
@python_task(cpu_limit="10000m", memory_limit="10000Mi")
def object_detection(wf_params, url, result, parsed_image):
    with utils.AutoDeletingTempDir('tmp') as tmpdir:
        request = urllib2.Request(url, headers=HEADERS)
        fname = '{}/image.jpg'.format(tmpdir.name)
        d = urllib2.urlopen(request)
        with open(fname, 'wb') as opfile:
            data = d.read()
            opfile.write(data)
        wf_params.logging.info("downloaded image")

        output_file = '{}/output.jpg'.format(tmpdir.name)
        output = download.detect(fname, output_file)
        scores = output["detection_scores"]
        classes = output["detection_classes"]
        category_index = output["category_index"]
        
        results = []
        for i in range(len(scores)):
            if scores[i] > MIN_SCORE:
                if classes[i] in six.viewkeys(category_index):
                  class_name = category_index[classes[i]]['name']
                else:
                  class_name = 'N/A'
                display_str = str(class_name)
                display_str = '{}: {}%'.format(display_str, int(100*scores[i]))
                results.append(display_str)

        parsed_image.set(output_file)
        result.set("\n".join(results))
    
@workflow_class
class ObjectDetector(object):
    image_url = Input(Types.String, required=True, help="Image of image to detect")
    object_detection = object_detection(url=image_url)
    output_result = Output(object_detection.outputs.result, sdk_type=Types.String)
    output_image = Output(object_detection.outputs.parsed_image, sdk_type=Types.Blob)
