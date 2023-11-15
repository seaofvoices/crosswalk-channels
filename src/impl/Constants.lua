return {
    GlobalContainerName = '__ReplicatedValues__$$',
    CounterContainerName = '_ReplicatedValuesCounters%%%',
    LocalPlayerContainerName = '___ReplicatedValues__**',
    ListTag = '_$LIST_TYPE' .. if _G.DEV then '' else tostring(math.random(1_000_000, 9_999_999)),
    ListLengthAttribute = '__ReplicatedValues__len_',
    ValueAttribute = '____value_',
}
