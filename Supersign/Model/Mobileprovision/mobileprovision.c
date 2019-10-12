//
//  mobileprovision_utils.c
//  supersign
//
//  Created by Kabir Oberai on 05/07/19.
//  Copyright © 2019 Kabir Oberai. All rights reserved.
//

#include <stdlib.h>
#include <string.h>
#include <openssl/pkcs7.h>
#include <openssl/x509.h>
#include <openssl/bio.h>
#include "mobileprovision.h"

struct mobileprovision {
    PKCS7 *raw;
};

static mobileprovision_t mobileprovision_create(PKCS7 *raw) {
    mobileprovision_t profile = malloc(sizeof(struct mobileprovision));
    profile->raw = raw;
    return profile;
}

mobileprovision_t mobileprovision_create_from_data(const char *data, size_t len) {
    PKCS7 *raw = NULL;
    d2i_PKCS7(&raw, (const unsigned char **)&data, len);
    if (!raw) return NULL;

    return mobileprovision_create(raw);
}

mobileprovision_t mobileprovision_create_from_path(const char *path) {
    BIO *file = BIO_new_file(path, "r");
    if (!file) return NULL;

    PKCS7 *raw = NULL;
    d2i_PKCS7_bio(file, &raw);

    BIO_free(file);

    return mobileprovision_create(raw);
}

void mobileprovision_free(mobileprovision_t profile) {
    PKCS7_free(profile->raw);
    free(profile);
}

char *mobileprovision_get_data(mobileprovision_t profile, size_t *len) {
    unsigned char *data = NULL;
    size_t data_len = i2d_PKCS7(profile->raw, &data);
    if (data_len < 0) return NULL;
    *len = data_len;
    return (char *)data;
}

const char *mobileprovision_get_digest(mobileprovision_t profile, size_t *len) {
    ASN1_OCTET_STRING *str = profile->raw->d.sign->contents->d.data;
    if (len) *len = str->length;
    return (char *)str->data;
}
