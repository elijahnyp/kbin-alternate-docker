<?php
// This assumes the S3 connection is available.
// Not great for bootstrapping where the bucket 
// is provisioned as part of the bootsrapping
// process
require '/srv/app/vendor/autoload.php';

$prefix = 'static';
$public_dir = '/srv/app/public';

function dirContents($dir){
    $files = scandir($dir);

    $results = array();

    foreach ($files as $key => $value){
        if($value == "." || $value == ".."){
            continue;
        }
        // echo $key . ": " . $value . "\n";
        $path = realpath($dir . DIRECTORY_SEPARATOR . $value);
        if (is_dir($path)) {
            // echo $path . "\n";
            $sub_results = dirContents($path);
            $results = array_merge($results, $sub_results);
        } else {
            $results[] = $path;
        }
    }
    return $results;
}


$files = dirContents($public_dir);

// var_dump($files);

$s3client = new Aws\S3\S3Client([
    'region' => getenv('S3_REGION'),
    'version' => getenv('S3_VERSION'),
    'credentials' => [
        'key' => getenv('S3_KEY'),
        'secret' => getenv('S3_SECRET')
    ],
    'endpoint' => getenv('S3_ENDPOINT'),
    'use_path_style_endpoint' => (bool)getenv('S3_USE_PATH_STYLE_ENDPOINT'),
]);

$locks = array();

try {
    $file = $s3client->getObject([
        'Bucket' => getenv('S3_BUCKET'),
        'Key' => $prefix . '/lockfile'
    ]);
    $body = $file->get('Body');
    $remote = unserialize($body);
} catch (Exception $exception) {
    if($exception->getAwsErrorCode() == 'NoSuchKey'){
        echo "\nNo Such Key\n";
    }
    else {
        echo "failed: " . $exception->getMessage();
    }
    $remote = array();
}

foreach ($files as $file){
    // echo $file . "\n";
    // echo substr($file, strlen($public_dir));
    // echo "\n\n";
    $sha1 = sha1_file($file);
    $basefile = substr($file, strlen($public_dir));
    if(!array_key_exists($basefile, $remote) || $sha1 != $remote[$basefile]){
        echo "\nUploading $file\n";
        try {
            $s3client->putObject([
                'Bucket' => getenv('S3_BUCKET'),
                'Key' => $prefix . $basefile,
                'SourceFile' => $file
            ]);
            $locks[$basefile] = $sha1;
        } catch (Exception $e){
            echo "Failed to upload $file with error: " . $e->getMessage();
        }
    } else {
        $locks[$basefile] = $sha1;
    }
}

foreach ($remote as $key => $value){
    if(! array_key_exists($key,$locks)){
        echo "\nDeleting object " . $prefix . $key . "\n";
        $s3client->deleteObject([
            'Bucket' => getenv('S3_BUCKET'),
            'Key' => $prefix . $key
        ]);
    }
}

$newlocks = serialize($locks);

try {
    $s3client->putObject([
        'Bucket' => getenv('S3_BUCKET'),
        'Key' => $prefix . '/lockfile',
        'Body' => $newlocks
    ]);
} catch (Exception $e){
    echo "\nFaild to upload $file with error: " . $exception->getMessage();
}