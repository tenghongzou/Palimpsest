// Package storage keeps uploaded files such as avatars and covers.
package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"
)

// Store saves an object and returns the URL browsers can fetch it from.
type Store interface {
	Put(ctx context.Context, key string, r io.Reader, size int64, contentType string) (string, error)
}

// PublicPrefix is the key prefix readable without credentials.
const PublicPrefix = "public/"

type minioStore struct {
	client    *minio.Client
	bucket    string
	publicURL string
}

// NewMinIO returns a Store on a MinIO (or S3) bucket. It creates the bucket
// if needed and makes keys under PublicPrefix anonymously readable.
func NewMinIO(ctx context.Context, client *minio.Client, bucket, publicURL string) (Store, error) {
	exists, err := client.BucketExists(ctx, bucket)
	if err != nil {
		return nil, err
	}
	if !exists {
		if err := client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{}); err != nil {
			return nil, err
		}
	}
	policy, _ := json.Marshal(map[string]interface{}{
		"Version": "2012-10-17",
		"Statement": []map[string]interface{}{{
			"Effect":    "Allow",
			"Principal": map[string]interface{}{"AWS": []string{"*"}},
			"Action":    []string{"s3:GetObject"},
			"Resource":  []string{fmt.Sprintf("arn:aws:s3:::%s/%s*", bucket, PublicPrefix)},
		}},
	})
	if err := client.SetBucketPolicy(ctx, bucket, string(policy)); err != nil {
		return nil, err
	}
	return &minioStore{client: client, bucket: bucket, publicURL: publicURL}, nil
}

func (s *minioStore) Put(ctx context.Context, key string, r io.Reader, size int64, contentType string) (string, error) {
	_, err := s.client.PutObject(ctx, s.bucket, key, r, size, minio.PutObjectOptions{
		ContentType:  contentType,
		CacheControl: "public, max-age=31536000, immutable",
	})
	if err != nil {
		return "", err
	}
	return s.publicURL + "/" + key, nil
}
