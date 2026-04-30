import { IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
  @IsString()
  @IsNotEmpty()
  nom_usuario: string;

  @IsString()
  @IsNotEmpty()
  password: string;
}
