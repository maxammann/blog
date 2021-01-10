


def decamelize(String key) {
    return String.join("_", StringUtils.splitByCharacterTypeCamelCase(key))
}