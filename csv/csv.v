module csv

import arrays
import encoding.csv
import os
import strconv

fn get_column(name string, columns []string) int {
        for i, val in columns {
                if val == name {
                        return i
                }
        }
        return -1
}

fn string_to_bool(val string) bool {
        l_val := val.to_lower().trim_space()
        if l_val == 'true' {
                return true
        }

        i_val := val.int()
        if i_val != 0 {
                return true
        }

        return false
}

fn csv_header(field_data FieldData) string {
        if field_data.attrs.len == 0 {
                return field_data.name
        }
        csv_attr := arrays.find_first(field_data.attrs, fn (attr string) bool {
                return attr.starts_with('csv:')
        }) or { return field_data.name }
        return csv_attr.replace('csv:', '').trim_space()
}


pub fn read_structs[T](file string) ![]T {
        mut result := []T{}
        mut reader := csv.new_reader_from_file(file) or { return error('Failed to read file') }
        mut column_names := []string{}
        mut i := 0
        mut dict := map[string]int{}

        for {
                values := reader.read() or { break }
                if i == 0 {
                        for value in values {
                                column_names << value
                        }
                        $for field in T.fields {
                                dict[field.name] = get_column(csv_header(field), column_names)
                        }
                } else {
                        mut record := T{}

                        $for field in T.fields {
                                key := field.name
                                mut col := dict[key]
                                if col > -1 && col < column_names.len {
                                        value := values[dict[key]]
                                        $if field.typ is string {
                                                record.$(field.name) = value
                                        } $else $if field.typ is int {
                                                record.$(field.name) = value.int()
                                        } $else $if field.typ is f32 {
                                                record.$(field.name) = f32(strconv.atof64(value) or { f32(0.0) })
                                        } $else $if field.typ is f64 {
                                                record.$(field.name) = strconv.atof64(value) or { f64(0.0) }
                                        } $else $if field.typ is bool {
                                                record.$(field.name) = string_to_bool(value)
                                        } $else {
                                                return error('Unsupported field type: ${field.typ.name}')
                                        }
                                }
                        }
                        result << record
                }
                i++
        }
        return result
}


pub fn write_structs[T](structs []T, file_path string) ! {
        mut headers := []string{}
        mut rows := [][]string{}
        $for field in T.fields {
                headers << field.name
        }

        for s in structs {
                mut values := []string{}
                $for field in T.fields {
                        values << s.$(field.name)
                }
                rows << values
        }

        mut writer := csv.new_writer()
        writer.write(headers) or {}
        for row in rows {
                writer.write(row) or {}
        }

        content := writer.str()
        os.write_file(file_path, content)!
}
